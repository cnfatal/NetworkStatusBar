//
//  StatusBarDetailsView.swift
//  NetworkStatusBar
//
//  Created by fatal cn on 2021/10/31.
//

import SwiftUI
import TabularData

struct StatusBarDetailsView: View {
    @ObservedObject var iostates = IOStates()
    var body: some View {
        List(iostates.items,id: \.pid){item in
            StatusBarDetailsItemView(state: item)
        }
        .listStyle(.sidebar)
    }
}

struct StatusBarDetailsItemView: View{
    var state: NetworkState = NetworkState()

    var body: some View{
        HStack(alignment: VerticalAlignment.center, spacing: 0){
            Text(state.name)
                .frame(width:140,alignment: Alignment.leading)
            VStack(alignment: .trailing){
                Text(String(format: "%@ ▲", arguments: [formatbytes(state.outbounds)]) )
                Text(String(format: "%@ ▼", arguments: [formatbytes(state.inbounds)]) )
            }
            .fixedSize()
            .font(.system(size: 9,weight: .medium))
            .frame(width: 60,alignment: Alignment.trailing)
        }
    }
}

struct StatusBarMenuView_Previews: PreviewProvider {
    static let  data =  { () -> IOStates in
        let ret  = IOStates()
        ret.items = [
            NetworkState(pid: 1, name: "process", inbounds: 512, outbounds: 512),
            NetworkState(pid: 2, name: "process", inbounds: 64, outbounds: 1)]
        return ret
    }()
    static var previews: some View {
        StatusBarDetailsView(iostates: data )
            .frame(width: 200.0)
    }
}

struct StatusBarDetailsItemView_Previews: PreviewProvider{
    static var previews: some View{
        StatusBarDetailsItemView(state: NetworkState(name: "process", inbounds: 1023, outbounds: 1000))
    }
}
