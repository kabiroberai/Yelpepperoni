import SwiftUI
import Common

@MainActor struct DetailView: View {
    let pizzeria: Pizzeria

    var body: some View {
        VStack {
            Form {
                LabeledContent(
                    "Address",
                    value: pizzeria.address
                )

                LabeledContent(
                    "Rating",
                    value: pizzeria.rating,
                    format: .number.precision(.fractionLength(1))
                )

                VStack {
                    Text("Photos")
                        .frame(
                            maxWidth: .infinity,
                            alignment: .leading
                        )

                    TabView {
                        ForEach(pizzeria.photos, id: \.id) {
                            PhotoView(photo: $0)
                        }
                    }
                    .tabViewStyle(.page)
                    .frame(height: 400)
                }
            }
        }
        .navigationTitle(pizzeria.name)
    }
}

#Preview {
    NavigationStack {
        DetailView(pizzeria: Pizzeria(
            id: "1",
            name: "My Pizzeria",
            address: "123 Pizza St",
            rating: 4.5,
            photos: [
                Pizzeria.Photo(
                    id: "abc",
                    filename: "foo.png",
                    description: "abc"
                )
            ]
        ))
    }
}
