import SwiftUI
import PhotosUI
import FirebaseFirestore
import Combine
import UIKit

@MainActor
final class BakerPortfolioViewModel: ObservableObject {
    @Published var works: [PortfolioWork] = []
    @Published var publishedWorkIDs: Set<String> = []
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var errorMessage = ""
    @Published var successMessage = ""

    let user: AppUser
    private let db = Firestore.firestore()

    init(user: AppUser) {
        self.user = user
    }

    func loadPortfolio() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let artisanSnapshot = try await db.collection("artisans").document(user.id).getDocument()
            let artisanData = artisanSnapshot.data() ?? [:]
            let publishedIDs = artisanData["portfolioPublishedWorkIDs"] as? [String] ?? []

            let snapshot = try await db.collection("artisans")
                .document(user.id)
                .collection("portfolioWorks")
                .order(by: "updatedAt", descending: true)
                .getDocuments()

            let loadedWorks = snapshot.documents.compactMap(PortfolioWork.init(document:))
            let validPublishedIDs = Set(publishedIDs.filter { workID in
                loadedWorks.contains(where: { $0.id == workID })
            })

            works = loadedWorks
            publishedWorkIDs = validPublishedIDs

            if Set(publishedIDs) != validPublishedIDs {
                try await persistPublishedSelection()
            }
        } catch {
            errorMessage = "Failed to load portfolio: \(error.localizedDescription)"
        }
    }

    func saveWork(from draft: PortfolioWorkDraft, editingWorkID: String?) async {
        let trimmedTitle = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = draft.description.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedTraits = draft.traits.compactMap { trait -> PortfolioTrait? in
            let trimmedName = trait.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedName.isEmpty else { return nil }
            return PortfolioTrait(id: trait.id, name: trimmedName, score: min(max(trait.score, 0), 100))
        }

        guard !trimmedTitle.isEmpty else {
            errorMessage = "Please enter a title for this work."
            return
        }

        guard !draft.imageBase64.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Please add a photo for this work."
            return
        }

        isSaving = true
        defer { isSaving = false }

        let now = Timestamp(date: Date())
        let workID = editingWorkID ?? UUID().uuidString
        let document = db.collection("artisans")
            .document(user.id)
            .collection("portfolioWorks")
            .document(workID)

        do {
            var payload: [String: Any] = [
                "title": trimmedTitle,
                "description": trimmedDescription,
                "imageBase64": draft.imageBase64,
                "traits": cleanedTraits.map(\.firestoreData),
                "updatedAt": now
            ]

            if editingWorkID == nil {
                payload["createdAt"] = now
            }

            try await document.setData(payload, merge: true)
            successMessage = editingWorkID == nil ? "Portfolio work added." : "Portfolio work updated."
            await loadPortfolio()

            if publishedWorkIDs.contains(workID) {
                try await persistPublishedSelection()
            }
        } catch {
            errorMessage = "Failed to save portfolio work: \(error.localizedDescription)"
        }
    }

    func deleteWork(_ work: PortfolioWork) async {
        isSaving = true
        defer { isSaving = false }

        do {
            try await db.collection("artisans")
                .document(user.id)
                .collection("portfolioWorks")
                .document(work.id)
                .delete()

            publishedWorkIDs.remove(work.id)
            works.removeAll { $0.id == work.id }
            try await persistPublishedSelection()
            successMessage = "Portfolio work deleted."
        } catch {
            errorMessage = "Failed to delete portfolio work: \(error.localizedDescription)"
        }
    }

    func togglePublished(for work: PortfolioWork) async {
        let isCurrentlyPublished = publishedWorkIDs.contains(work.id)

        if isCurrentlyPublished {
            publishedWorkIDs.remove(work.id)
        } else {
            guard publishedWorkIDs.count < 6 else {
                errorMessage = "You can publish up to 6 works in your profile."
                return
            }
            publishedWorkIDs.insert(work.id)
        }

        do {
            try await persistPublishedSelection()
            successMessage = isCurrentlyPublished ? "Removed from profile portfolio." : "Published to profile portfolio."
        } catch {
            if isCurrentlyPublished {
                publishedWorkIDs.insert(work.id)
            } else {
                publishedWorkIDs.remove(work.id)
            }
            errorMessage = "Failed to update published works: \(error.localizedDescription)"
        }
    }

    private func persistPublishedSelection() async throws {
        let orderedPublishedWorks = publishedWorks
        let publishedIDs = orderedPublishedWorks.map(\.id)
        let publishedSummaries = orderedPublishedWorks.map(\.publishedSummary)
        let legacyImages = orderedPublishedWorks.map(\.imageBase64).filter { !$0.isEmpty }

        try await db.collection("artisans").document(user.id).setData([
            "portfolioPublishedWorkIDs": publishedIDs,
            "portfolioPublishedWorks": publishedSummaries,
            "portfolioImages": legacyImages,
            "portfolioUpdatedAt": Timestamp(date: Date())
        ], merge: true)

        let batch = db.batch()
        for work in works {
            let ref = db.collection("artisans")
                .document(user.id)
                .collection("portfolioWorks")
                .document(work.id)
            batch.setData(["isPublished": publishedIDs.contains(work.id)], forDocument: ref, merge: true)
        }
        try await batch.commit()
        NotificationCenter.default.post(name: Notification.Name("bakerPortfolioDidChange"), object: nil)
    }

    var publishedWorks: [PortfolioWork] {
        return works.filter { publishedWorkIDs.contains($0.id) }
    }
}

struct BakerPortfolioManagerView: View {
    let user: AppUser

    @StateObject private var viewModel: BakerPortfolioViewModel
    @State private var draft = PortfolioWorkDraft.empty
    @State private var editingWorkID: String?
    @State private var isPresentingEditor = false
    @State private var workPendingDelete: PortfolioWork?

    @Environment(\.dismiss) private var dismiss

    init(user: AppUser) {
        self.user = user
        _viewModel = StateObject(wrappedValue: BakerPortfolioViewModel(user: user))
    }

    var body: some View {
        ZStack {
            Color.cakeBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        portfolioSummaryCard
                        publishedPreviewSection
                        worksSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 104)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(true)
        .asBakerSubScreen()
        .task {
            await viewModel.loadPortfolio()
        }
        .sheet(isPresented: $isPresentingEditor) {
            PortfolioWorkEditorSheet(
                draft: $draft,
                isSaving: viewModel.isSaving,
                onSave: {
                    Task {
                        await viewModel.saveWork(from: draft, editingWorkID: editingWorkID)
                        if viewModel.errorMessage.isEmpty {
                            isPresentingEditor = false
                            draft = .empty
                            editingWorkID = nil
                        }
                    }
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .alert("Delete work?", isPresented: deleteAlertBinding) {
            Button("Delete", role: .destructive) {
                guard let workPendingDelete else { return }
                Task {
                    await viewModel.deleteWork(workPendingDelete)
                    self.workPendingDelete = nil
                }
            }
            Button("Cancel", role: .cancel) {
                workPendingDelete = nil
            }
        } message: {
            Text("This will remove the work from your portfolio and profile.")
        }
        .alert("Error", isPresented: errorAlertBinding) {
            Button("OK") {
                viewModel.errorMessage = ""
            }
        } message: {
            Text(viewModel.errorMessage)
        }
        .alert("Success", isPresented: successAlertBinding) {
            Button("OK") {
                viewModel.successMessage = ""
            }
        } message: {
            Text(viewModel.successMessage)
        }
    }

    private var deleteAlertBinding: Binding<Bool> {
        Binding(
            get: { workPendingDelete != nil },
            set: { isPresented in
                if !isPresented { workPendingDelete = nil }
            }
        )
    }

    private var errorAlertBinding: Binding<Bool> {
        Binding(
            get: { !viewModel.errorMessage.isEmpty },
            set: { isPresented in
                if !isPresented { viewModel.errorMessage = "" }
            }
        )
    }

    private var successAlertBinding: Binding<Bool> {
        Binding(
            get: { !viewModel.successMessage.isEmpty },
            set: { isPresented in
                if !isPresented { viewModel.successMessage = "" }
            }
        )
    }

    private var headerBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.cakeBrown)
            }

            Spacer()

            Text("Edit Portfolio")
                .font(.urbanistBold(18))
                .foregroundColor(Color(hex: "5D3714"))

            Spacer()

            Color.clear.frame(width: 24, height: 24)
        }
        .padding(.horizontal, 20)
        .frame(height: 56)
        .background(Color.cakeSurface)
    }

    private var portfolioSummaryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Show your best work")
                        .font(.urbanistBold(18))
                        .foregroundColor(Color(hex: "5D3714"))
                    Text("Add past cakes, describe the work, and choose up to 6 pieces to publish in your profile portfolio.")
                        .font(.urbanistRegular(13))
                        .foregroundColor(.cakeGrey)
                        .lineSpacing(3)
                }
                Spacer()
            }

            HStack(spacing: 12) {
                summaryBadge(
                    title: "Saved Works",
                    value: "\(viewModel.works.count)",
                    tint: Color(hex: "F1EFEC")
                )
                summaryBadge(
                    title: "Published",
                    value: "\(viewModel.publishedWorkIDs.count)/6",
                    tint: Color(hex: "F1EFEC")
                )
            }

            Button {
                startCreatingWork()
            } label: {
                Text("Add Previous Work")
                    .font(.urbanistBold(14))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color.cakeBrown)
                    .clipShape(Capsule())
            }
        }
        .padding(18)
        .background(Color.cakeSurface)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
    }

    private func summaryBadge(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.urbanistMedium(12))
                .foregroundColor(.cakeGrey)
            Text(value)
                .font(.urbanistBold(18))
                .foregroundColor(Color(hex: "5D3714"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(tint)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var publishedPreviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Published In Profile")
                    .font(.urbanistBold(16))
                    .foregroundColor(Color(hex: "5D3714"))
                Spacer()
                Text("\(viewModel.publishedWorkIDs.count) selected")
                    .font(.urbanistRegular(12))
                    .foregroundColor(.cakeGrey)
            }

            if viewModel.publishedWorks.isEmpty {
                emptyStateCard(
                    icon: "photo.on.rectangle.angled",
                    title: "No published works yet",
                    message: "Select the works you want to show inside the My Portfolio area on your profile."
                )
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(viewModel.publishedWorks.prefix(6)) { work in
                            VStack(alignment: .center, spacing: 8) {
                                PortfolioWorkImageView(imageBase64: work.imageBase64, height: 110)
                                Text(work.title)
                                    .font(.urbanistSemiBold(13))
                                    .foregroundColor(Color(hex: "5D3714"))
                                    .lineLimit(1)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(width: 132)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(18)
        .background(Color.cakeSurface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
    }

    private var worksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Added Works")
                    .font(.urbanistBold(16))
                    .foregroundColor(Color(hex: "5D3714"))
                Spacer()
                if viewModel.isLoading {
                    ProgressView()
                        .tint(.cakeBrown)
                }
            }

            if viewModel.works.isEmpty, !viewModel.isLoading {
                emptyStateCard(
                    icon: "birthday.cake",
                    title: "Your portfolio is empty",
                    message: "Add your previous cake work here, then choose which 6 works should appear on your profile."
                )
            } else {
                VStack(spacing: 14) {
                    ForEach(viewModel.works) { work in
                        PortfolioWorkCard(
                            work: work,
                            isPublished: viewModel.publishedWorkIDs.contains(work.id),
                            onTogglePublished: {
                                Task { await viewModel.togglePublished(for: work) }
                            },
                            onEdit: {
                                startEditing(work)
                            },
                            onDelete: {
                                workPendingDelete = work
                            }
                        )
                    }
                }
            }
        }
    }

    private func emptyStateCard(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundColor(.cakeBrown.opacity(0.7))
            Text(title)
                .font(.urbanistBold(15))
                .foregroundColor(Color(hex: "5D3714"))
            Text(message)
                .font(.urbanistRegular(12))
                .foregroundColor(.cakeGrey)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(Color.cakeInsetSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func startCreatingWork() {
        draft = .empty
        editingWorkID = nil
        isPresentingEditor = true
    }

    private func startEditing(_ work: PortfolioWork) {
        draft = PortfolioWorkDraft(work: work)
        editingWorkID = work.id
        isPresentingEditor = true
    }
}

struct PortfolioWorkCard: View {
    let work: PortfolioWork
    let isPublished: Bool
    var showsActions: Bool = true
    let onTogglePublished: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .topTrailing) {
                PortfolioWorkImageView(imageBase64: work.imageBase64, height: 150)

                if showsActions {
                    Text(isPublished ? "Published" : "Draft")
                        .font(.urbanistBold(11))
                        .foregroundColor(isPublished ? Color(red: 0.17, green: 0.53, blue: 0.23) : Color.cakeBrown)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(isPublished ? Color(red: 0.86, green: 0.95, blue: 0.86) : Color.white.opacity(0.92))
                        .clipShape(Capsule())
                        .padding(10)
                }
            }

            VStack(alignment: .leading, spacing: 7) {
                Text(work.title)
                    .font(.urbanistBold(16))
                    .foregroundColor(Color(hex: "5D3714"))

                if !work.description.isEmpty {
                    Text(work.description)
                        .font(.urbanistRegular(13))
                        .foregroundColor(.cakeGrey)
                        .lineSpacing(3)
                }

                if !work.traits.isEmpty {
                    VStack(spacing: 10) {
                        ForEach(work.traits) { trait in
                            PortfolioTraitBar(trait: trait)
                        }
                    }
                    .padding(.top, 2)
                }
            }

            if showsActions {
                HStack(spacing: 10) {
                    Button(action: onTogglePublished) {
                        Text(isPublished ? "Remove From Profile" : "Publish To Profile")
                            .font(.urbanistBold(13))
                            .foregroundColor(isPublished ? .white : .cakeBrown)
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .background(isPublished ? Color.cakeBrown : Color.cakeBrown.opacity(0.12))
                            .clipShape(Capsule())
                    }

                    Button(action: onEdit) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.cakeBrown)
                            .frame(width: 40, height: 40)
                            .background(Color.cakeInsetSurface)
                            .clipShape(Circle())
                    }

                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.red.opacity(0.85))
                            .frame(width: 40, height: 40)
                            .background(Color.red.opacity(0.08))
                            .clipShape(Circle())
                    }
                }
            }
        }
        .padding(14)
        .background(Color.cakeSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 3)
    }
}

private struct PortfolioWorkEditorSheet: View {
    @Binding var draft: PortfolioWorkDraft
    let isSaving: Bool
    let onSave: () -> Void

    @State private var selectedPhotoItem: PhotosPickerItem?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.cakeBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    photoSection
                    detailsSection
                    traitsSection
                    saveButton
                }
                .padding(20)
                .padding(.bottom, 20)
            }
            }
        }
        .onChange(of: selectedPhotoItem) { _, item in
            Task {
                guard let data = try await item?.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else { return }
                draft.imageBase64 = encodeImageToBase64(image)
            }
        }
    }

    private var headerBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.cakeBrown)
            }

            Spacer()

            Text("Portfolio Work")
                .font(.urbanistBold(18))
                .foregroundColor(Color(red: 0.365, green: 0.216, blue: 0.078))

            Spacer()

            Color.white.frame(width: 24)
        }
        .padding(.horizontal, 20)
        .frame(height: 56)
        .background(Color.cakeSurface)
    }

    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Photo")
                .font(.urbanistBold(15))
                .foregroundColor(Color(hex: "5D3714"))

            PortfolioWorkImageView(imageBase64: draft.imageBase64, height: 220)

            PhotosPicker(selection: $selectedPhotoItem, matching: .images, photoLibrary: .shared()) {
                Text(draft.imageBase64.isEmpty ? "Choose Photo" : "Change Photo")
                    .font(.urbanistBold(13))
                    .foregroundColor(.cakeBrown)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.cakeBrown.opacity(0.12))
                    .clipShape(Capsule())
            }
        }
    }

    private var detailsSection: some View {
        VStack(spacing: 16) {
            editorField(label: "Title", placeholder: "e.g. Royal Wedding Cake", text: $draft.title)

            VStack(alignment: .leading, spacing: 8) {
                Text("Description")
                    .font(.urbanistBold(14))
                    .foregroundColor(Color(hex: "5D3714"))

                TextEditor(text: $draft.description)
                    .font(.urbanistRegular(14))
                    .frame(height: 120)
                    .padding(8)
                    .background(Color.cakeSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.black.opacity(0.14), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    private var traitsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Talent Traits")
                    .font(.urbanistBold(15))
                    .foregroundColor(Color(hex: "5D3714"))
                Spacer()
                Button {
                    draft.traits.append(PortfolioTraitDraft())
                } label: {
                    Text("Add Trait")
                        .font(.urbanistMedium(13))
                        .foregroundColor(.cakeBrown)
                }
            }

            if draft.traits.isEmpty {
                Text("Add traits like creativity, finishing, fondant work, or detailing.")
                    .font(.urbanistRegular(12))
                    .foregroundColor(.cakeGrey)
            } else {
                ForEach($draft.traits) { $trait in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 10) {
                            TextField("Trait name", text: $trait.name)
                                .font(.urbanistRegular(14))
                                .padding(.horizontal, 14)
                                .frame(height: 44)
                                .background(Color.cakeSurface)
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(Color.black.opacity(0.14), lineWidth: 1)
                                )

                            Button {
                                draft.traits.removeAll { $0.id == trait.id }
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 22))
                                    .foregroundColor(.red.opacity(0.85))
                            }
                        }

                        HStack(spacing: 12) {
                            Slider(
                                value: Binding(
                                    get: { Double(trait.score) },
                                    set: { trait.score = Int($0.rounded()) }
                                ),
                                in: 0...100,
                                step: 1
                            )
                            .tint(.cakeBrown)

                            Text("\(trait.score)%")
                                .font(.urbanistSemiBold(13))
                                .foregroundColor(Color(hex: "5D3714"))
                                .frame(width: 44, alignment: .trailing)
                        }
                    }
                    .padding(14)
                    .background(Color(hex: "F0EDEA"))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
        }
    }

    private var saveButton: some View {
        Button {
            onSave()
        } label: {
            Text(isSaving ? "Saving..." : "Save Portfolio Work")
                .font(.urbanistBold(15))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.cakeBrown)
                .clipShape(Capsule())
        }
        .disabled(isSaving)
        .opacity(isSaving ? 0.6 : 1)
    }

    private func editorField(label: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.urbanistBold(14))
                .foregroundColor(Color(hex: "5D3714"))

            TextField(placeholder, text: text)
                .font(.urbanistRegular(14))
                .padding(.horizontal, 14)
                .frame(height: 46)
                .background(Color.cakeSurface)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color.black.opacity(0.14), lineWidth: 1)
                )
        }
    }

    private func encodeImageToBase64(_ image: UIImage) -> String {
        image.jpegData(compressionQuality: 0.35)?.base64EncodedString() ?? ""
    }
}

struct PortfolioWorkImageView: View {
    let imageBase64: String
    let height: CGFloat

    var body: some View {
        Group {
            if let image = decodeBase64Image(imageBase64) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                LinearGradient(
                    colors: [
                        Color(red: 0.94, green: 0.88, blue: 0.82),
                        Color(red: 0.88, green: 0.80, blue: 0.73)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .overlay(
                    Image(systemName: "birthday.cake.fill")
                        .font(.system(size: 34))
                        .foregroundColor(.white.opacity(0.9))
                )
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func decodeBase64Image(_ rawBase64: String) -> UIImage? {
        let trimmed = rawBase64.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let payload: String
        if let commaIndex = trimmed.firstIndex(of: ",") {
            payload = String(trimmed[trimmed.index(after: commaIndex)...])
        } else {
            payload = trimmed
        }

        guard let data = Data(base64Encoded: payload) else { return nil }
        return UIImage(data: data)
    }
}

struct PortfolioTraitBar: View {
    let trait: PortfolioTrait

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(trait.name)
                    .font(.urbanistMedium(12))
                    .foregroundColor(Color(hex: "5D3714"))
                Spacer()
                Text("\(trait.score)%")
                    .font(.urbanistSemiBold(12))
                    .foregroundColor(.cakeGrey)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(hex: "A59688").opacity(0.20))
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(hex: "A59688"))
                        .frame(width: geo.size.width * CGFloat(trait.score) / 100)
                }
            }
            .frame(height: 10)
        }
    }
}

struct PortfolioWork: Identifiable, Hashable {
    let id: String
    let title: String
    let description: String
    let imageBase64: String
    let traits: [PortfolioTrait]
    let createdAt: Date
    let updatedAt: Date

    init(
        id: String,
        title: String,
        description: String,
        imageBase64: String,
        traits: [PortfolioTrait],
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.imageBase64 = imageBase64
        self.traits = traits
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init?(document: QueryDocumentSnapshot) {
        let data = document.data()
        let title = (data["title"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let imageBase64 = data["imageBase64"] as? String ?? ""
        guard !title.isEmpty, !imageBase64.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }

        let traitsData = data["traits"] as? [[String: Any]] ?? []
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue() ?? createdAt

        self.init(
            id: document.documentID,
            title: title,
            description: (data["description"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
            imageBase64: imageBase64,
            traits: traitsData.compactMap(PortfolioTrait.init(dictionary:)),
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    var publishedSummary: [String: Any] {
        [
            "workID": id,
            "title": title,
            "description": description,
            "imageBase64": imageBase64,
            "traits": traits.map(\.firestoreData),
            "updatedAt": Timestamp(date: updatedAt)
        ]
    }
}

struct PortfolioTrait: Identifiable, Hashable {
    let id: String
    let name: String
    let score: Int

    init(id: String = UUID().uuidString, name: String, score: Int) {
        self.id = id
        self.name = name
        self.score = score
    }

    nonisolated init?(dictionary: [String: Any]) {
        let name = (dictionary["name"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }
        self.id = dictionary["id"] as? String ?? UUID().uuidString
        self.name = name
        if let score = dictionary["score"] as? Int {
            self.score = score
        } else if let score = dictionary["score"] as? Double {
            self.score = Int(score.rounded())
        } else {
            self.score = 0
        }
    }

    var firestoreData: [String: Any] {
        [
            "id": id,
            "name": name,
            "score": score
        ]
    }
}

struct PortfolioWorkDraft {
    var title: String
    var description: String
    var imageBase64: String
    var traits: [PortfolioTraitDraft]

    static let empty = PortfolioWorkDraft(
        title: "",
        description: "",
        imageBase64: "",
        traits: [
            PortfolioTraitDraft(name: "Creativity", score: 88),
            PortfolioTraitDraft(name: "Finishing", score: 92)
        ]
    )

    init(title: String, description: String, imageBase64: String, traits: [PortfolioTraitDraft]) {
        self.title = title
        self.description = description
        self.imageBase64 = imageBase64
        self.traits = traits
    }

    init(work: PortfolioWork) {
        self.title = work.title
        self.description = work.description
        self.imageBase64 = work.imageBase64
        self.traits = work.traits.map { PortfolioTraitDraft(id: $0.id, name: $0.name, score: $0.score) }
    }
}

struct PortfolioTraitDraft: Identifiable {
    let id: String
    var name: String
    var score: Int

    init(id: String = UUID().uuidString, name: String = "", score: Int = 80) {
        self.id = id
        self.name = name
        self.score = score
    }
}
