import SwiftUI

struct BakerDistrictPickerSheet: View {
    let districts: [String]
    let selectedDistrict: String?
    let onSelect: (String) -> Void

    var body: some View {
        NavigationStack {
            List(districts, id: \.self) { district in
                Button {
                    onSelect(district)
                } label: {
                    HStack {
                        Text(district)
                            .foregroundColor(.primary)
                        Spacer()
                        if selectedDistrict == district {
                            Image(systemName: "checkmark")
                                .foregroundColor(.cakeBrown)
                        }
                    }
                }
            }
            .navigationTitle("Select District")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
