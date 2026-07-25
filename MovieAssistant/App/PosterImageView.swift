import SwiftUI
import AVFoundation

/// Постер фильма из бандла (Resources/Posters/poster_<id>.jpg) с запасным
/// градиентом на случай, если для конкретного id постера нет — архитектура
/// не завязана на то, что постеры обязательно есть у каждого фильма в базе.
struct PosterImageView: View {
    let movieId: Int

    var body: some View {
        if let uiImage = Self.cachedImage(for: movieId) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            LinearGradient(
                colors: AppTheme.Colors.posterGradient(for: movieId),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .overlay(
                Image(systemName: "film")
                    .font(.system(size: 28))
                    .foregroundStyle(.white.opacity(0.85))
            )
        }
    }

    private static var cache: [Int: UIImage] = [:]

    private static func cachedImage(for id: Int) -> UIImage? {
        if let cached = cache[id] { return cached }
        guard let url = Bundle.main.url(forResource: "poster_\(id)", withExtension: "jpg"),
              let image = UIImage(contentsOfFile: url.path) else {
            return nil
        }
        cache[id] = image
        return image
    }
}

/// Общая загрузка кадров фильма из бандла (Resources/Stills/still_<id>_<1...5>.jpg),
/// с кэшем — используется и лентой в рулетке, и каруселью на странице фильма,
/// чтобы не читать одни и те же файлы с диска дважды.
enum MovieStillsLoader {
    private static var cache: [String: UIImage] = [:]

    static func images(for movieId: Int) -> [UIImage] {
        (1...5).compactMap { cachedImage(for: movieId, index: $0) }
    }

    private static func cachedImage(for movieId: Int, index: Int) -> UIImage? {
        let key = "\(movieId)_\(index)"
        if let cached = cache[key] { return cached }
        let name = "still_\(movieId)_\(index)"
        // Ищем и внутри подпапки Stills (если её добавили в Xcode как "folder
        // reference" — тогда новые файлы подхватываются сами, без похода в Xcode),
        // и в корне бандла (если как обычную группу, как раньше сделано с постерами).
        let url = Bundle.main.url(forResource: name, withExtension: "jpg", subdirectory: "Stills")
            ?? Bundle.main.url(forResource: name, withExtension: "jpg")
        guard let url, let image = UIImage(contentsOfFile: url.path) else {
            return nil
        }
        cache[key] = image
        return image
    }
}

/// Карусель на странице фильма сразу под постером: первая страница — всегда
/// постер фильма (тот же баннер, что и в каталоге), дальше — трейлер (Resources/
/// Trailers/trailer_<id>.mp4), если он есть, без звука, сам переключается на
/// кадры по окончании; кадры дальше листаются каждые 1.5 секунды (через .task,
/// а не Timer/Combine — так цикл не плодится заново при каждой перерисовке
/// родителя) и никогда не возвращаются к постеру/видео сами. Автопрокрутка
/// приостанавливается, пока карусель не видна на экране (проскроллена мимо) —
/// иначе к моменту, когда до неё долистают обратно, она уже "убежала" на
/// несколько кадров вперёд.
struct MovieStillsCarouselView: View {
    let movieId: Int
    /// false — без подписи "Кадры из фильма"/"Трейлер и кадры" сверху, для
    /// мест, где карусель — это весь верх карточки, а не подписанная секция.
    var showsHeading: Bool = true
    /// nil — карусель растягивается на всю доступную высоту (карточка свайпа),
    /// иначе фиксированная высота (страница фильма, результат рулетки).
    var fixedHeight: CGFloat? = 200
    /// false — без постера первой страницей: там, где постер уже показан
    /// отдельно рядом (например, большой hero-баннер на странице фильма),
    /// повторять его в самой карусели незачем.
    var showsPoster: Bool = true

    @State private var index = 0
    /// Как только пользователь сам потянул за карусель — больше не перехватываем
    /// у него управление автопрокруткой до конца жизни этого экрана.
    @State private var isAutoAdvancing = true
    /// Видна ли карусель прямо сейчас в своём скролле — обновляется через
    /// onScrollVisibilityChange, чтобы не листать фон, пока не смотрят.
    @State private var isVisible = true
    @State private var player: AVPlayer?
    @State private var isMuted = true
    @State private var endObserver: NSObjectProtocol?

    private var images: [UIImage] { MovieStillsLoader.images(for: movieId) }
    private var trailerURL: URL? { TrailerLoader.url(for: movieId) }
    private var hasTrailer: Bool { trailerURL != nil }
    private var posterPageCount: Int { showsPoster ? 1 : 0 }
    /// Индекс страницы с видео, если оно есть — на ней таймер не листает сам,
    /// дальше пускает только конец ролика; пауза/продолжение — ручной свайп.
    private var videoPageIndex: Int? { hasTrailer ? posterPageCount : nil }
    /// Индекс первой страницы с кадром — после постера (если есть) и видео (если есть).
    private var firstStillIndex: Int { posterPageCount + (hasTrailer ? 1 : 0) }
    private var pageCount: Int { posterPageCount + (hasTrailer ? 1 : 0) + images.count }

    var body: some View {
        if pageCount > 0 {
            VStack(alignment: .leading, spacing: 8) {
                if showsHeading {
                    Text(hasTrailer ? "Трейлер и кадры" : "Кадры из фильма")
                        .font(AppTheme.Typography.headline)
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                }

                Group {
                    if let fixedHeight {
                        pagesTabView.frame(height: fixedHeight)
                    } else {
                        pagesTabView.frame(maxHeight: .infinity)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Layout.cornerRadius))
                // simultaneousGesture — не отбирает свайп у самого TabView,
                // просто дополнительно узнаёт о ручном перелистывании.
                .simultaneousGesture(
                    DragGesture(minimumDistance: 8).onChanged { _ in isAutoAdvancing = false }
                )
                .onScrollVisibilityChange { visible in isVisible = visible }

                if pageCount > 1 {
                    HStack(spacing: 6) {
                        ForEach(0..<pageCount, id: \.self) { i in
                            Circle()
                                .fill(i == index ? AppTheme.Colors.accent : AppTheme.Colors.divider)
                                .frame(width: 6, height: 6)
                        }
                    }
                }
            }
            .onAppear(perform: setUpTrailerIfNeeded)
            .onDisappear {
                if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
                player?.pause()
            }
            // Ролик играет, только когда он реально на экране: и открыт нужной
            // страницей карусели, и сама карусель не улистана из вида. Иначе он
            // продолжал играть (а после включения звука — и звучать) фоном,
            // например когда карточку в списке рекомендаций проскроллили мимо.
            .onChange(of: index) { _, _ in syncPlayback() }
            .onChange(of: isVisible) { _, _ in syncPlayback() }
            .task {
                guard pageCount > 1 else { return }
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(1.5))
                    guard isAutoAdvancing, isVisible, index != videoPageIndex else { continue }
                    withAnimation {
                        if index >= pageCount - 1 {
                            // Конец кадров — крутим их по кругу, но не возвращаемся
                            // к постеру/видео; если кадр всего один, просто остаёмся на нём.
                            if images.count > 1 { index = firstStillIndex }
                        } else {
                            index += 1
                        }
                    }
                }
            }
        }
    }

    private var pagesTabView: some View {
        TabView(selection: $index) {
            if showsPoster {
                PosterImageView(movieId: movieId).tag(0)
            }
            if hasTrailer {
                trailerPage.tag(posterPageCount)
            }
            ForEach(images.indices, id: \.self) { i in
                Image(uiImage: images[i])
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .tag(firstStillIndex + i)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
    }

    /// Страница с видео — без системных элементов плеера (они бы спорили за
    /// жесты со свайпом между страницами): просто картинка + своя кнопка звука.
    private var trailerPage: some View {
        ZStack(alignment: .bottomTrailing) {
            if let player {
                SilentVideoLayerView(player: player)
            } else {
                Color.black
            }
            Button {
                isMuted.toggle()
                player?.isMuted = isMuted
            } label: {
                Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(8)
                    .background(Circle().fill(.black.opacity(0.45)))
            }
            .padding(10)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            isMuted.toggle()
            player?.isMuted = isMuted
        }
    }

    /// Единственное место, где решается, должен ли ролик сейчас играть —
    /// чтобы условие не разъезжалось между обработчиками страницы и видимости.
    private func syncPlayback() {
        guard let player, let videoPageIndex else { return }
        guard index == videoPageIndex, isVisible else {
            player.pause()
            return
        }
        // Ролик уже доиграл до конца (на кадры ушли автоматически, а потом
        // пользователь вернулся к нему свайпом) — начинаем заново, иначе он
        // просто застыл бы на последнем кадре.
        if let item = player.currentItem, item.duration.isValid, !item.duration.isIndefinite,
           player.currentTime() >= item.duration {
            player.seek(to: .zero)
        }
        player.play()
    }

    private func setUpTrailerIfNeeded() {
        guard hasTrailer, player == nil, let trailerURL else { return }
        // Без явной категории .playback система по умолчанию душит звук плеера
        // на переключателе "без звука" — тогда кнопка звука включается визуально,
        // а слышно всё равно ничего не будет.
        try? AVAudioSession.sharedInstance().setCategory(.playback)
        try? AVAudioSession.sharedInstance().setActive(true)
        let newPlayer = AVPlayer(url: trailerURL)
        newPlayer.isMuted = true
        player = newPlayer
        // Стартуем, только если видео уже открытая страница (на странице фильма
        // постера в карусели нет, и ролик идёт первым). Если перед ним постер —
        // ждём, пока до видео долистают, иначе оно отыграет первые секунды
        // впустую, пока его ещё не видно. Дальше playback ведёт syncPlayback.
        if index == videoPageIndex && isVisible {
            newPlayer.play()
        }

        // Конец ролика — переключаемся на первый кадр, если он есть; если кадров
        // нет вообще, просто оставляем последний кадр видео на экране.
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: newPlayer.currentItem,
            queue: .main
        ) { _ in
            guard !images.isEmpty else { return }
            withAnimation { index = firstStillIndex }
        }
    }
}

/// Голый видеослой без элементов управления плеера — используется для тихого
/// автовоспроизведения внутри карусели, где своя кнопка звука и свайп между
/// страницами важнее стандартных controls AVKit.
private struct SilentVideoLayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerContainerView {
        let view = PlayerContainerView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PlayerContainerView, context: Context) {
        uiView.playerLayer.player = player
    }

    final class PlayerContainerView: UIView {
        override static var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }
}
