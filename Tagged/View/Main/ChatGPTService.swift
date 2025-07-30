import Foundation

struct ChatGPTService {
    private let endpoint = URL(string: "https://api.openai.com/v1/chat/completions")!
    private let apiKey: String
    
    init(apiKey: String? = nil) {
        if let path = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
           let dict = NSDictionary(contentsOfFile: path) as? [String: Any],
           let key = dict["OPENAI_API_KEY"] as? String {
            self.apiKey = key
        } else {
            self.apiKey = ""
        }
    }
    
    func generateTag(description: String, existingTags: [String]) async throws -> String {
        let prompt = """
        Based on this description: \(description), create ONE short, trendy, and aesthetic tag for a photo challenge group.
        The tag should sound NORMAL and STRAIGHTFORWARD AND give a clear idea of what to take a photo of (e.g., outfit, food, sunset, desk setup).
        Do NOT repeat or use anything similar to these tags: \(existingTags.joined(separator: ", ")).
        Keep it under 6 words. No emojis. No hashtags. No quotes.

        Examples: My Fit Today, Sunset Glow, Favorite Drink, Coffee Aesthetic, Daily Street Shot.
        Now, give me just one unique tag.
        """

        let requestBody: [String: Any] = [
            "model": "gpt-4o",
            "messages": [
                ["role": "system", "content": "You create short, trendy tags for a Gen-Z photo challenge app & don't try too hard to sound cool."],
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.9,
            "max_tokens": 30
        ]
        
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            return "Error generating"
        }

        let decoded = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        let content = decoded.choices.first?.message.content
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'")) ?? ""

        return content.isEmpty ? "Error generating" : content
    }
}

struct OpenAIResponse: Codable {
    let choices: [Choice]
    struct Choice: Codable {
        let message: Message
        struct Message: Codable {
            let content: String
        }
    }
}
