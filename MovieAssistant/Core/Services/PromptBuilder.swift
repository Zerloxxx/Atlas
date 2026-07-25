import Foundation

/// Собирает system/user промпты для рекомендательного запроса.
/// Единственное место, где формулируется ограничение "рекомендуй только из каталога" —
/// требование PROJECT_SPEC.md.
enum PromptBuilder {
    static func systemPrompt() -> String {
        """
        Ты — узкоспециализированный AI-ассистент ТОЛЬКО по подбору фильмов и сериалов внутри
        онлайн-кинотеатра. Ты не общий чат-бот и не отвечаешь на вопросы не по теме (математика,
        факты, погода, программирование, общие разговоры и т.п.) — даже если можешь. Если сообщение
        пользователя (обычно это поле "Текстовый запрос пользователя" в сценарии чата) не связано с
        выбором фильма или сериала, не пытайся притянуть его к рекомендации. Вместо этого поставь
        "offTopic": true и в "message" вежливо, можно с лёгким юмором, объясни, что помогаешь только
        с подбором фильмов, и предложи спросить про кино.

        Тебе передан список фильмов из локальной базы в поле "каталог" и профиль предпочтений пользователя.
        У каждого фильма в каталоге есть: id, название, год, жанры, режиссёр, актёры, темы, атмосфера,
        особенности сюжета, длительность, тип концовки, синопсис. Используй ВСЕ эти поля для отбора,
        а не только жанр.

        Как отбирать:
        - Если пользователь называет конкретного актёра или режиссёра — в первую очередь ищи фильмы
          в каталоге с их участием.
        - Если таких фильмов мало или нет — дополняй подборку фильмами БЕЗ этого человека, но похожими
          по жанру, теме, атмосфере или сюжету на то, что описал пользователь. Явно объясняй в explanation,
          по какому именно признаку взят такой фильм (например: "тоже боевик с похожей динамикой, но без
          Джейсона Стэйтема").
        - Если пользователь описывает несколько разных предпочтений (актёр + жанр + настроение и т.д.) —
          учитывай все одновременно, а не только первое.
        - КАЖДАЯ рекомендация обязана сохранять хотя бы одну сильную связь с тем, что указал пользователь:
          тот же актёр/режиссёр, ИЛИ тот же жанр, ИЛИ явное сходство темы/сюжета/атмосферы с тем, что ему
          понравилось. Никогда не рекомендуй фильм, у которого нет вообще ничего общего, только потому что
          где-то "жанр тоже другой" — "другой жанр" значит смени жанр, но не теряй остальные точки совпадения.
        - Если в сценарии "подбор по фильму" пользователь выбрал "Ничего, найдите похожее" — не меняй ничего
          намеренно, ищи максимально близкие по жанру, теме, атмосфере и, если есть, актёрам/режиссёру фильмы.
        - Если указаны нежелательные жанры ("не хочет видеть") — ни один рекомендованный фильм не должен
          относиться к этим жанрам, это жёсткое ограничение, а не пожелание.
        - Если сценарий "Смотрим вместе" — в профиле по набору предпочтений на каждого из нескольких
          участников (может быть 2, 3, 4 и больше — смотри, сколько именно наборов передано).
          Сначала проверь, есть ли в каталоге фильм, чьи СОБСТВЕННЫЕ жанры (поле "genres") уже
          покрывают жанры сразу нескольких участников одновременно (например, кто-то хочет боевик,
          кто-то драму — ищи фильм, у которого в genres есть и "Боевик", и "Драма") — такой фильм
          почти всегда лучший компромисс, и его нужно предпочесть в первую очередь. Только если
          в каталоге совсем нет фильма с пересечением жанров, тогда ищи объединяющее по
          атмосфере/теме/настроению — но не подменяй реальное пересечение жанров натянутой аналогией,
          если прямое совпадение есть и ты его просто не заметил.
          Каждая рекомендация должна разумно подходить ВСЕМ участникам сразу: либо удовлетворяет
          жанр/настроение большинства одновременно, либо явно объясняй в explanation, чем именно
          фильм понравится каждому (например: "первому — динамичный сюжет боевика, второму —
          эмоциональная драма отношений, третьему — атмосфера триллера").
        - Если передана история прошлых оценок пользователя — учитывай её как дополнительный контекст о вкусе
          (какие темы/жанры/атмосфера ему заходят по факту, не только по словам), но НЕ как единственный
          сигнал: явные предпочтения в текущем запросе всегда важнее истории.

        Правила:
        1. Рекомендуй ТОЛЬКО фильмы, чей "id" есть в переданном каталоге. Никогда не придумывай фильмы, которых нет в списке.
        2. Выбери от 3 до 5 наиболее подходящих фильмов, отсортированных от самого подходящего к менее подходящему.
        3. Для каждого фильма напиши короткое (1-2 предложения) объяснение на русском языке, почему он подходит именно этому пользователю — ссылайся на конкретные предпочтения, которые он указал (актёра, режиссёра, жанр, тему, атмосферу — что именно совпало), а не общими фразами.
        4. Для каждого фильма оцени числом от 0 до 100, насколько он совпадает с предпочтениями пользователя (matchScore) — это должна быть содержательная, а не случайная оценка: чем больше точек совпадения (актёр/жанр/тема/атмосфера/настроение), тем выше число.
        5. Ответ верни строго в формате JSON без текста вне JSON, в точности такой структуры:
        {"offTopic": <true/false>, "message": "<текст на русском, только если offTopic=true, иначе пустая строка>", "recommendations": [{"movieId": <id из каталога>, "matchScore": <0-100>, "explanation": "<текст на русском>"}]}
        6. Если "offTopic": true — "recommendations" должен быть пустым массивом [].
        """
    }

    static func userPrompt(profile: UserPreferenceProfile, catalog: [Movie]) -> String {
        let genreOverlapHint = togetherGenreOverlapHint(profile: profile, catalog: catalog)
            .map { "\n\($0)\n" } ?? ""
        return """
        Каталог фильмов (JSON):
        \(encodeCatalog(catalog))

        Профиль предпочтений пользователя:
        \(describe(profile))
        \(genreOverlapHint)
        Верни JSON с рекомендациями по описанным правилам.
        """
    }

    /// Модель не всегда сама замечает пересечение жанров между участниками
    /// "Смотрим вместе" и вместо этого натягивает атмосферное сходство там, где
    /// в каталоге прямо есть фильм с обоими жанрами — считаем это точно в коде
    /// и передаём готовым списком, а не полагаемся на то, что ИИ сам заметит.
    private static func togetherGenreOverlapHint(profile: UserPreferenceProfile, catalog: [Movie]) -> String? {
        guard case .together = profile.source, profile.togetherParticipants.count >= 2 else { return nil }
        let participantGenres = profile.togetherParticipants.map { Set($0.genres) }
        guard participantGenres.contains(where: { !$0.isEmpty }) else { return nil }

        let matches = catalog.compactMap { movie -> (movie: Movie, matchedParticipants: Int)? in
            let movieGenres = Set(movie.genres)
            let matchedCount = participantGenres.filter { !$0.isEmpty && !$0.isDisjoint(with: movieGenres) }.count
            guard matchedCount >= 2 else { return nil }
            return (movie, matchedCount)
        }
        .sorted { $0.matchedParticipants > $1.matchedParticipants }
        .prefix(6)

        guard !matches.isEmpty else { return nil }

        let lines = matches.map { entry in
            "id \(entry.movie.id) «\(entry.movie.title)» (жанры: \(entry.movie.genres.joined(separator: ", "))) — совпадает сразу с \(entry.matchedParticipants) участниками"
        }
        return """
        ВАЖНО (посчитано точно алгоритмом по полю genres, а не твоей оценкой): в каталоге уже есть фильмы, чьи жанры одновременно покрывают запросы нескольких участников:
        \(lines.joined(separator: "\n"))
        Предпочти один из них, если он разумно подходит и по остальным критериям (настроение/тема) — это почти всегда лучший компромисс, чем фильм с натянутым объяснением через атмосферу вместо реального жанра. Если ни один из них вообще не подходит по смыслу — тогда ищи по атмосфере/теме, но честно объясняй это как сходство по атмосфере, а не выдавай за жанровое совпадение.
        """
    }

    private static func encodeCatalog(_ catalog: [Movie]) -> String {
        let compact = catalog.map { movie in
            CompactMovie(
                id: movie.id,
                title: movie.title,
                year: movie.year,
                genres: movie.genres,
                director: movie.director,
                actors: movie.actors,
                themes: movie.themes,
                atmosphere: movie.atmosphere,
                plotFeatures: movie.plotFeatures,
                durationMinutes: movie.durationMinutes,
                endingType: movie.endingType,
                synopsis: movie.synopsis
            )
        }
        guard let data = try? JSONEncoder().encode(compact),
              let string = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return string
    }

    private static func describe(_ profile: UserPreferenceProfile) -> String {
        var lines: [String] = []

        switch profile.source {
        case .quickPick:
            lines.append("Сценарий: быстрый подбор (пользователь не знал точно, что хочет посмотреть).")
        case .movieBased(let referenceMovieId):
            lines.append("Сценарий: подбор по понравившемуся фильму (id референсного фильма в каталоге: \(referenceMovieId)).")
        case .chat:
            lines.append("Сценарий: свободный текстовый запрос в чате.")
        case .together:
            lines.append("Сценарий: «Смотрим вместе» — нужно найти компромисс между предпочтениями \(profile.togetherParticipants.count) участников.")
        case .swipeMatch(let likedMovieIds):
            lines.append("Сценарий: «Мэтчи» — пользователь просвайпал подборку и лайкнул несколько фильмов (id в каталоге: \(likedMovieIds.map(String.init).joined(separator: ", "))). Найди похожие по жанру, теме, атмосфере или актёрам/режиссёру фильмы, не повторяя сами лайкнутые.")
        }

        if !profile.genres.isEmpty {
            lines.append("Желаемые жанры: \(profile.genres.joined(separator: ", "))")
        }
        if !profile.importantAspects.isEmpty {
            lines.append("Что важно пользователю: \(profile.importantAspects.joined(separator: ", "))")
        }
        if !profile.mood.isEmpty {
            lines.append("Желаемое настроение: \(profile.mood.joined(separator: ", "))")
        }
        if let duration = profile.durationPreference {
            lines.append("Предпочтение по длительности: \(duration)")
        }
        if !profile.excludedGenres.isEmpty {
            lines.append("Не хочет видеть жанры (жёсткое ограничение): \(profile.excludedGenres.joined(separator: ", "))")
        }
        if !profile.likedAspects.isEmpty {
            lines.append("Что понравилось в референсном фильме: \(profile.likedAspects.joined(separator: ", "))")
        }
        if !profile.likedActors.isEmpty {
            lines.append("Понравившиеся актёры: \(profile.likedActors.joined(separator: ", "))")
        }
        if !profile.likedPlotFeatures.isEmpty {
            lines.append("Понравившиеся особенности сюжета: \(profile.likedPlotFeatures.joined(separator: ", "))")
        }
        if !profile.likedAtmosphere.isEmpty {
            lines.append("Понравившаяся атмосфера: \(profile.likedAtmosphere.joined(separator: ", "))")
        }
        if !profile.wantsToChange.isEmpty {
            lines.append("Что хочется изменить по сравнению с референсным фильмом: \(profile.wantsToChange.joined(separator: ", "))")
        }
        if let freeText = profile.freeTextQuery {
            lines.append("Текстовый запрос пользователя: \"\(freeText)\"")
        }
        for (index, participant) in profile.togetherParticipants.enumerated() {
            let genres = participant.genres.isEmpty ? "не указано" : participant.genres.joined(separator: ", ")
            let mood = participant.mood.isEmpty ? "не указано" : participant.mood.joined(separator: ", ")
            lines.append("Участник \(index + 1) из \(profile.togetherParticipants.count) — желаемый жанр: \(genres); желаемое настроение: \(mood)")
        }
        if let tasteHistory = profile.tasteHistorySummary {
            lines.append("История прошлых оценок пользователя (доп. контекст, не жёсткое правило): \(tasteHistory)")
        }
        if let swipeLikes = profile.swipeLikesSummary {
            lines.append("Фильмы, которые пользователь лайкнул в свайп-подборе (доп. контекст о вкусе, не жёсткое правило): \(swipeLikes)")
        }

        return lines.joined(separator: "\n")
    }

    private struct CompactMovie: Encodable {
        let id: Int
        let title: String
        let year: Int
        let genres: [String]
        let director: String
        let actors: [String]
        let themes: [String]
        let atmosphere: [String]
        let plotFeatures: [String]
        let durationMinutes: Int
        let endingType: String
        let synopsis: String
    }
}
