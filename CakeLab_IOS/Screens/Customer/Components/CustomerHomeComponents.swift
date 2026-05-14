import SwiftUI


// Reusable card for displaying a baker/artisan profile in list context.
struct ArtisanCard: View {
    let name: String
    let rating: String
    let reviews: String
    let specialty: [String]
    let location: String
    var isOnline: Bool = true
    var imageURL: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(red: 0.92, green: 0.90, blue: 0.87))
                        .frame(width: 72, height: 72)
                    Image(systemName: "storefront.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.cakeBrown.opacity(0.5))
                }
                VStack(alignment: .leading, spacing: 5) {
                    Text(name)
                        .font(.urbanistBold(14))
                        .foregroundColor(.cakePrimaryText)
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 11))
                            .foregroundColor(Color(red: 1.0, green: 0.78, blue: 0.1))
                        Text(rating)
                            .font(.urbanistSemiBold(12))
                            .foregroundColor(.cakePrimaryText)
                        Text(reviews)
                            .font(.urbanistRegular(11))
                            .foregroundColor(.cakeGrey)
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(specialty, id: \.self) { tag in
                                Text(tag)
                                    .font(.urbanistRegular(10))
                                    .foregroundColor(.cakeBrown)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.cakeBrown.opacity(0.12))
                                    .cornerRadius(10)
                            }
                        }
                    }
                }
                Spacer()
                Circle()
                    .fill(isOnline ? Color(red: 0.15, green: 0.72, blue: 0.25) : Color.gray.opacity(0.4))
                    .frame(width: 11, height: 11)
            }
            HStack(spacing: 5) {
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.cakeGrey)
                Text(location)
                    .font(.urbanistRegular(11))
                    .foregroundColor(.cakeGrey)
                    .lineLimit(1)
            }
        }
        .padding(12)
        .background(Color.cakeSurface)
        .cornerRadius(14)
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
    }
}
