import SwiftUI

struct HelpView: View {
    
    @Binding var path: NavigationPath
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                
                Text("Contact Us")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundColor(.accentColor)
                
                HStack(alignment: .firstTextBaseline) {
                    Text("Website:")
                        .fontWeight(.bold)
                    Link("tagged-start.web.app", destination: URL(string: "https://tagged-start.web.app")!)
                }
                
                HStack(alignment: .firstTextBaseline) {
                    Text("TikTok:")
                        .fontWeight(.bold)
                    Link("@tagged_app", destination: URL(string: "https://www.tiktok.com/@tagged_app?_t=ZM-8xA4bfUXSuD&_r=1")!)
                }
                
                HStack(alignment: .firstTextBaseline) {
                    Text("Email:")
                        .fontWeight(.bold)
                    Link("starttagged@gmail.com", destination: URL(string: "mailto:starttagged@gmail.com")!)
                }
            }
            .padding(.leading, 15)
            .padding(.top)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationBarBackButtonHidden(false)
    }
}
