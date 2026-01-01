//
//  TestSwiftUIView.swift
//  SimpleImageCachingDemo
//
//  Created by Jae hyung Kim on 12/29/25.
//

import SwiftUI
import SimpleImageCachingSwift

struct TestSwiftUIView: View {
    
    private let imageURLs: [String] = (1...120).map { index in
//        "https://picsum.photos/id/\(index)/200/300"
        eTagBaseUrlString + eTagTrailingUrlStrings[index]
    }
    
    var body: some View {
        List {
            ForEach(imageURLs, id: \.self) { item in
                SICView(urlString: item, options: [
                    .cacheOption(.diskAndMemory),
                    .resize(type: .jpeg, targetMB: 0.1)
                ])
                .contentMode(.fill)
                .placeHolder(UIImage(systemName: "house")!)
                .onSuccess { image in
                    print("success url = \(item)")
                }
                .onFailure { error in
                    print("error - \(error.localizedDescription)")
                }
                .resizable()
                .frame(height: 200)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
            }
        }
        
    }
}

#if DEBUG
#Preview {
    TestSwiftUIView()
}
#endif
