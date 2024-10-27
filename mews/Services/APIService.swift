//
//  APIService.swift
//  mews
//
//  Created by Desmond Fitch on 10/27/24.
//

import SwiftUI

struct APIService {
    @MainActor
    static func fetchSongsBrowsed(for userID: String) async -> Int? {
        guard let url = URL(string: "https://app.lochsports.com:8080/user/songsBrowsed/\(userID)") else {
            print("Invalid URL")
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10.0

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) {
                // Print the raw JSON data for debugging
                if let rawResponse = String(data: data, encoding: .utf8) {
                    print("Raw JSON Response: \(rawResponse)")
                }

                do {
                    if let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                        // Debugging: Print entire JSON response
                        print("Full JSON Response: \(jsonResponse)")

                        // Access the specific keys
                        if let songsBrowsed = jsonResponse["songs_browsed"] as? Int {
                            print("User \(userID) has browsed \(songsBrowsed) songs.")
                            return songsBrowsed
                        } else {
                            print("Unable to find 'songs_browsed' key in JSON response.")
                        }
                    }
                } catch {
                    print("Error parsing JSON response: \(error.localizedDescription)")
                }
            } else {
                print("Invalid response from server")
            }
        } catch {
            print("Error fetching data: \(error.localizedDescription)")
        }
        return nil
    }
    
    @MainActor
    static func updateSongsBrowsed(for userID: String, count: Int) async {
        guard let url = URL(string: "https://app.lochsports.com:8080/user/songsBrowsed/\(userID)") else {
            print("Invalid URL")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // JSON body data
        let body: [String: Any] = [
            "songsBrowsed": count
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
            
            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) {
                do {
                    if let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                        print("POST Response: \(jsonResponse)")
                        
                        // Check for individual fields in the response
                        if let message = jsonResponse["message"] as? String,
                           let status = jsonResponse["status"] as? String,
                           let updatedSongsBrowsed = jsonResponse["songs_browsed"] as? Int,
                           let returnedUserId = jsonResponse["userId"] as? String {
                            print("Message: \(message), Status: \(status), Songs Browsed: \(updatedSongsBrowsed), User ID: \(returnedUserId)")
                        } else {
                            print("Response keys not as expected")
                        }
                    }
                } catch {
                    print("Error parsing JSON response: \(error.localizedDescription)")
                }
            } else {
                print("Invalid response from server")
            }
        } catch {
            print("Error posting data: \(error.localizedDescription)")
        }
    }
}
