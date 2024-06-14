//
//  SettingView.swift
//  QiniuSwiftDemo
//
//  Created by yangsen on 2024/6/13.
//

import SwiftUI

struct SettingCellModel: Hashable, Identifiable {
    let id = UUID()
    
	let title: String
	var Value: String
}

struct SettingGroupModel: Hashable, Identifiable {
    let id = UUID()
    
    let title: String
    let models: [SettingCellModel]
}



struct SettingCell: View {
    @State var cellModel: SettingCellModel
    
	var body: some View {
		HStack {
            Text("\(cellModel.title):").foregroundStyle(kMainColor)
            TextField("请输入\(cellModel.title)", text: $cellModel.Value)
		}
			.padding()
	}
}


struct SettingView: View {

    private let cellDatas: [SettingGroupModel] = [
		SettingGroupModel(title: "00", models: [
			SettingCellModel(title: "a", Value:"a"),
            SettingCellModel(title: "a", Value:"a"),
        ])
	]

    @State private var singleSelection: UUID?
    
	var body: some View {
		VStack {
            List(selection: $singleSelection) {
                ForEach(cellDatas) { group in
                    // 分组
                    Section(header: Text(group.title)) {
                        
                        ForEach(group.models) { model in
                            SettingCell(cellModel: model)
                        }
                    }
                }
            }.selectionDisabled()
		}
	}
}

#Preview {
	SettingView()
}
