import SwiftUI

struct HelpView: View {
    
    @Binding var path: NavigationPath
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                
                Text("Contact Us")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundColor(.accentColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                HStack(alignment: .firstTextBaseline) {
                    Text("Website:")
                        .fontWeight(.bold)
                        .frame(width: 75, alignment: .leading)
                    Link("tagged-start.web.app", destination: URL(string: "https://tagged-start.web.app")!)
                }

                HStack(alignment: .firstTextBaseline) {
                    Text("TikTok:")
                        .fontWeight(.bold)
                        .frame(width: 75, alignment: .leading)
                    Link("@tagged_app", destination: URL(string: "https://www.tiktok.com/@tagged_app?_t=ZM-8xA4bfUXSuD&_r=1")!)
                }

                HStack(alignment: .firstTextBaseline) {
                    Text("Email:")
                        .fontWeight(.bold)
                        .frame(width: 75, alignment: .leading)
                    Link("starttagged@gmail.com", destination: URL(string: "mailto:starttagged@gmail.com")!)
                }
            }
            .padding(.horizontal, 15) 
            .padding(.top, 18)
        }
        .navigationTitle("Help")
    }
}
