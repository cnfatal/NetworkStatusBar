//
//  StatusBarView.swift
//  NetworkStatusBar
//
//  Created by fatal cn on 2021/10/31.
//

import SwiftUI


class IOStates:ObservableObject{
    @Published var total:NetworkState = NetworkState()
    @Published var items:[NetworkState] = []
}


struct StatusBarView: View {
    @ObservedObject var iostates = IOStates()
    var body: some View {
            VStack{
                Text(String(format: "%@ ▲", arguments: [formatbytes(iostates.total.outbounds)]) )
                Text(String(format: "%@ ▼", arguments: [formatbytes(iostates.total.inbounds)]) )
            }
            .font(.system(size: 9,weight: .medium))
            .frame(alignment: .leading)
    }
}

struct StatusBarView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            StatusBarView()
        }
    }
}

func formatbytes(_ bytes:Int)->String {
    return String(format: "%@/s", arguments: [
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: ByteCountFormatter.CountStyle.binary)
    ])
 }
