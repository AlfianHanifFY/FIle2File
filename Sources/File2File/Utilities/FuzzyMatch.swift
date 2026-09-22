import Foundation

public struct FuzzyMatch {
    public static func autoMapColumns(sqlColumns: [ColumnSchema], excelHeaders: [String]) -> [ColumnMapping] {
        return sqlColumns.map { col in
            let match = findBestMatch(target: col.name, candidates: excelHeaders)
            let isDateOrTime = col.dataType.contains("DATE") || col.dataType.contains("TIME")
            
            return ColumnMapping(
                sqlColumn: col.name,
                sqlType: col.dataType,
                isNullable: col.isNullable,
                excelHeader: match.header,
                confidence: match.score,
                dateFormat: isDateOrTime ? "AUTO" : "",
                nullHandling: .setNull,
                defaultValue: ""
            )
        }
    }

    private static func normalize(_ str: String) -> String {
        return str.lowercased().replacingOccurrences(of: "[^a-z0-9]", with: "", options: .regularExpression)
    }

    private static func tokenize(_ str: String) -> [String] {
        let clean = str.lowercased()
            .replacingOccurrences(of: "[^a-z0-9\\s_]", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "_", with: " ")
        return clean.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
    }

    private static func findBestMatch(target: String, candidates: [String]) -> (header: String, score: Double) {
        guard !candidates.isEmpty else { return ("", 0.0) }

        let normTarget = normalize(target)
        let targetTokens = tokenize(target)

        var bestHeader = ""
        var maxScore = 0.0

        for candidate in candidates {
            let normCand = normalize(candidate)
            let candTokens = tokenize(candidate)

            // 1. Exact normalized match
            if normTarget == normCand {
                return (candidate, 1.0)
            }

            // 2. Token overlap score
            var tokenMatches = 0
            for tTok in targetTokens {
                for cTok in candTokens {
                    if tTok == cTok || (tTok.count > 3 && cTok.contains(tTok)) || (cTok.count > 3 && tTok.contains(cTok)) {
                        tokenMatches += 1
                        break
                    }
                }
            }

            let tokenScore = Double(tokenMatches) / Double(max(targetTokens.count, 1))

            // Semantic alias boosts
            let dateKeywords = ["date", "time", "created", "timestamp", "at", "updated"]
            let isDateTarget = targetTokens.contains(where: { dateKeywords.contains($0) })
            let isDateCand = candTokens.contains(where: { dateKeywords.contains($0) })

            let amountKeywords = ["amount", "total", "price", "cost", "sum", "val", "value"]
            let isAmountTarget = targetTokens.contains(where: { amountKeywords.contains($0) })
            let isAmountCand = candTokens.contains(where: { amountKeywords.contains($0) })

            var score = tokenScore * 0.8

            if isDateTarget && isDateCand { score += 0.3 }
            if isAmountTarget && isAmountCand { score += 0.3 }
            if normTarget.contains(normCand) || normCand.contains(normTarget) { score += 0.2 }

            score = min(1.0, score)

            if score > maxScore {
                maxScore = score
                bestHeader = candidate
            }
        }

        let roundedScore = (maxScore * 100.0).rounded() / 100.0
        return (roundedScore >= 0.4 ? bestHeader : "", roundedScore)
    }
}
