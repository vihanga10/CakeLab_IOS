import SwiftUI
import PhotosUI
import FirebaseAuth
import FirebaseFirestore

// MARK: - Create Cake Request View
struct CreateCakeRequestView: View {
    
    @Environment(\.dismiss) private var dismiss
    
    // Cake Details
    @State private var title          = ""
    @State private var description    = ""
    @State private var expectedDate   = Date()
    @State private var expectedTime   = Date()
    @State private var showDatePicker = false
    @State private var showTimePicker = false
    @State private var refImages: [PhotosPickerItem] = []
    
    // Budget
    @State private var budgetMin: Double = 5000
    @State private var budgetMax: Double = 10000
    
    // Specifications
    @State private var selectedCategories: Set<String> = []
    @State private var selectedStyles:     Set<String> = []
    @State private var selectedDietary:    Set<String> = []
    @State private var selectedTier:       Int?         = nil
    @State private var cakeSize           = ""
    @State private var sugarLevel: Double = 0.5
    @State private var selectedFlavours:   Set<String> = []
    @State private var fillingFlavour     = ""
    @State private var specialInstructions = ""
    @State private var allowNearby        = false
    
    private let categories  = ["Wedding Cake", "Anniversary Cake", "Cupcakes", "Birthday Cake",
                               "Baby Shower", "3D Cake", "Engagement Cake"]
    @State private var cakeStyles   = ["Buttercream", "Fondant", "Floral", "Rustic", "Drip", "Naked"]
    @State private var dietaryOpts  = ["Gluten Free", "Nut Free", "Soy-Free", "Vegan", "Sugar-Free"]
    @State private var flavours     = ["Vanilla", "Chocolate", "Red Velvet", "Strawberry",
                                       "Lemon", "Caramel", "Black Forest"]
    
    // Camera & navigation
    @State private var showCamera         = false
    @State private var cameraImage: UIImage?          = nil
    @State private var isSaving = false
    @State private var showSuccessAlert = false
    @State private var successMessage = ""
    
    // Tier add
    @State private var showAddTierAlert = false
    @State private var newTierText      = ""
    @State private var extraTiers: [Int] = []
    
    private var allTiers: [Int] { Array(1...7) + extraTiers }
    
    private var dateFormatter: DateFormatter {
        let f = DateFormatter(); f.dateStyle = .medium; return f
    }
    private var timeFormatter: DateFormatter {
        let f = DateFormatter(); f.timeStyle = .short; return f
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            Color.white.ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    
                    // ── Cake Details Section ──────────────────────────────
                    sectionHeader("Cake Details")
                    
                    VStack(spacing: 14) {
                        
                        // Title
                        fieldBlock(label: "Title") {
                            TextField("e.g. Wedding Cake with Choco Chips", text: $title)
                                .font(.urbanistRegular(14))
                                .foregroundColor(Color(red: 0.2, green: 0.2, blue: 0.2))
                        }
                        
                        // Description
                        fieldBlock(label: "Description") {
                            ZStack(alignment: .topLeading) {
                                if description.isEmpty {
                                    Text("Tell us exactly how you want your cake made......")
                                        .font(.urbanistRegular(13))
                                        .foregroundColor(Color(red: 0.7, green: 0.7, blue: 0.7))
                                        .padding(.top, 2)
                                }
                                TextEditor(text: $description)
                                    .font(.urbanistRegular(14))
                                    .frame(minHeight: 80)
                                    .scrollContentBackground(.hidden)
                                    .background(.clear)
                            }
                        }
                        
                        // Date + Time row
                        HStack(spacing: 12) {
                            // Expected Date
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Expected Date")
                                    .font(.urbanistSemiBold(13))
                                    .foregroundColor(.cakeBrown)
                                Button { showDatePicker = true } label: {
                                    HStack {
                                        Text(dateFormatter.string(from: expectedDate))
                                            .font(.urbanistRegular(13))
                                            .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.3))
                                        Spacer()
                                        Image(systemName: "calendar")
                                            .font(.system(size: 14))
                                            .foregroundColor(.cakeGrey)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color(red: 0.85, green: 0.85, blue: 0.85), lineWidth: 1)
                                    )
                                }
                            }
                            .frame(maxWidth: .infinity)
                            
                            // Expected Time
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Expected Time")
                                    .font(.urbanistSemiBold(13))
                                    .foregroundColor(.cakeBrown)
                                Button { showTimePicker = true } label: {
                                    HStack {
                                        Text(timeFormatter.string(from: expectedTime))
                                            .font(.urbanistRegular(13))
                                            .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.3))
                                        Spacer()
                                        Image(systemName: "chevron.down")
                                            .font(.system(size: 12))
                                            .foregroundColor(.cakeGrey)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color(red: 0.85, green: 0.85, blue: 0.85), lineWidth: 1)
                                    )
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(16)
                    .background(Color.white)
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                    
                    // ── Reference Images ──────────────────────────────────
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Add Reference Image")
                            .font(.urbanistSemiBold(14))
                            .foregroundColor(.cakeBrown)
                        
                        HStack(spacing: 16) {
                            PhotosPicker(selection: $refImages, maxSelectionCount: 5,
                                         matching: .images) {
                                ImagePickerButton(icon: "photo", label: "Gallery")
                            }
                            
                            Button { showCamera = true } label: {
                                ImagePickerButton(icon: "camera", label: "Camera")
                            }
                            
                            if let img = cameraImage {
                                Image(uiImage: img)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 72, height: 72)
                                    .cornerRadius(10)
                                    .clipped()
                            }
                            Spacer()
                        }
                    }
                    .padding(16)
                    .background(Color.white)
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                    
                    // ── Cake Specifications Section ───────────────────────
                    sectionHeader("Cake Specifications")
                    
                    VStack(spacing: 18) {
                        
                        // Budget Range Slider
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Budget")
                                    .font(.urbanistSemiBold(14))
                                    .foregroundColor(.cakeBrown)
                                Spacer()
                                Text("\(Int(budgetMin).formatted()) – \(Int(budgetMax).formatted()) LKR")
                                    .font(.urbanistSemiBold(13))
                                    .foregroundColor(Color(red: 0.15, green: 0.15, blue: 0.15))
                            }
                            BudgetRangeSlider(minVal: $budgetMin, maxVal: $budgetMax)
                            HStack {
                                Text("Rs. 0.00")
                                    .font(.urbanistRegular(10))
                                    .foregroundColor(.cakeGrey)
                                Spacer()
                                Text("Rs. 100000+")
                                    .font(.urbanistRegular(10))
                                    .foregroundColor(.cakeGrey)
                            }
                        }
                        
                        specDivider()
                        
                        // Category
                        ChipSelector(
                            title: "Category",
                            helpText: "Choose main category",
                            options: .constant(categories),
                            selected: $selectedCategories,
                            showAddButton: false
                        )
                        
                        specDivider()
                        
                        // Cake Style
                        ChipSelector(
                            title: "Cake Style",
                            helpText: "Choose Cake Style",
                            options: $cakeStyles,
                            selected: $selectedStyles
                        )
                        
                        specDivider()
                        
                        // Dietary
                        ChipSelector(
                            title: "Dietary",
                            helpText: "Choose Dietary",
                            options: $dietaryOpts,
                            selected: $selectedDietary
                        )
                        
                        specDivider()
                        
                        // Tiers
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 4) {
                                Text("Tiers")
                                    .font(.urbanistSemiBold(14))
                                    .foregroundColor(.cakeBrown)
                                Text("( Choose Tiers )")
                                    .font(.urbanistRegular(12))
                                    .foregroundColor(.cakeGrey)
                                Spacer()
                                Button { showAddTierAlert = true } label: {
                                    Image(systemName: "plus.circle")
                                        .font(.system(size: 18))
                                        .foregroundColor(.cakeBrown)
                                }
                            }
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(allTiers, id: \.self) { n in
                                        Button { selectedTier = (selectedTier == n) ? nil : n } label: {
                                            ZStack {
                                                Circle()
                                                    .fill(selectedTier == n ? Color.cakeBrown : Color.white)
                                                Circle()
                                                    .stroke(Color(red: 0.80, green: 0.80, blue: 0.80), lineWidth: 1.5)
                                                Text("\(n)")
                                                    .font(.urbanistSemiBold(13))
                                                    .foregroundColor(selectedTier == n ? .white : Color(red: 0.2, green: 0.2, blue: 0.2))
                                            }
                                            .frame(width: 36, height: 36)
                                        }
                                    }
                                }
                            }
                        }
                        .alert("Add Tier", isPresented: $showAddTierAlert) {
                            TextField("Enter tier number (e.g. 8)", text: $newTierText)
                                .keyboardType(.numberPad)
                            Button("Add") {
                                if let n = Int(newTierText.trimmingCharacters(in: .whitespaces)),
                                   n > 0, !allTiers.contains(n) {
                                    extraTiers.append(n)
                                }
                                newTierText = ""
                            }
                            Button("Cancel", role: .cancel) { newTierText = "" }
                        }
                        
                        specDivider()
                        
                        // Cake Size
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Cake size")
                                .font(.urbanistSemiBold(14))
                                .foregroundColor(.cakeBrown)
                            TextField("IE g. 5 Kg size 10-20 people", text: $cakeSize)
                                .font(.urbanistRegular(14))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color(red: 0.85, green: 0.85, blue: 0.85), lineWidth: 1)
                                )
                        }
                        
                        specDivider()
                        
                        // Sugar Level
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Sugar Level")
                                    .font(.urbanistSemiBold(14))
                                    .foregroundColor(.cakeBrown)
                                Spacer()
                                Text("\(Int(sugarLevel * 100))%")
                                    .font(.urbanistSemiBold(13))
                                    .foregroundColor(.cakeBrown)
                            }
                            Slider(value: $sugarLevel, in: 0...1)
                                .tint(.cakeBrown)
                            HStack {
                                Text("0%\nsugar level")
                                    .font(.urbanistRegular(9))
                                    .foregroundColor(.cakeGrey)
                                    .multilineTextAlignment(.leading)
                                Spacer()
                                Text("50%\nsugar level")
                                    .font(.urbanistRegular(9))
                                    .foregroundColor(.cakeGrey)
                                    .multilineTextAlignment(.center)
                                Spacer()
                                Text("100%\nsugar level")
                                    .font(.urbanistRegular(9))
                                    .foregroundColor(.cakeGrey)
                                    .multilineTextAlignment(.trailing)
                            }
                        }
                        
                        specDivider()
                        
                        // Cake Flavour
                        ChipSelector(
                            title: "Cake Flavour",
                            helpText: "Choose Cake Flavor",
                            options: $flavours,
                            selected: $selectedFlavours
                        )
                        
                        specDivider()
                        
                        // Filling Flavour
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Filling Flavour")
                                .font(.urbanistSemiBold(14))
                                .foregroundColor(.cakeBrown)
                            TextField("Enter Filling Flavor", text: $fillingFlavour)
                                .font(.urbanistRegular(14))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color(red: 0.85, green: 0.85, blue: 0.85), lineWidth: 1)
                                )
                        }
                        
                        specDivider()
                        
                        // Special Instructions
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Special Instructions")
                                .font(.urbanistSemiBold(14))
                                .foregroundColor(.cakeBrown)
                            ZStack(alignment: .topLeading) {
                                if specialInstructions.isEmpty {
                                    Text("Enter Special Instructions......")
                                        .font(.urbanistRegular(13))
                                        .foregroundColor(Color(red: 0.7, green: 0.7, blue: 0.7))
                                        .padding(.top, 2)
                                }
                                TextEditor(text: $specialInstructions)
                                    .font(.urbanistRegular(14))
                                    .frame(minHeight: 80)
                                    .scrollContentBackground(.hidden)
                                    .background(.clear)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(red: 0.85, green: 0.85, blue: 0.85), lineWidth: 1)
                            )
                        }
                    }
                    .padding(16)
                    .background(Color.white)
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                    
                    // ── Nearby Toggle ─────────────────────────────────────
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Allow nearby Cake Crafters to see\nthis request")
                                .font(.urbanistSemiBold(13))
                                .foregroundColor(Color(red: 0.15, green: 0.15, blue: 0.15))
                            HStack(spacing: 4) {
                                Image(systemName: "info.circle.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.cakeGrey)
                                Text("When turned ON, your request will be shown to bakers near your location (within ~5 km).")
                                    .font(.urbanistRegular(10))
                                    .foregroundColor(.cakeGrey)
                                    .lineSpacing(2)
                            }
                        }
                        Spacer()
                        Toggle("", isOn: $allowNearby)
                            .tint(.cakeBrown)
                            .labelsHidden()
                    }
                    .padding(16)
                    .background(Color.white)
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 100) // bottom action bar clearance
                }
                .padding(.top, 8)
            }
            
            // ── Bottom Action Bar ─────────────────────────────────────
            HStack(spacing: 12) {
                Button {
                    Task {
                        await publishRequest()
                    }
                } label: {
                    if isSaving {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Publish Cake Request")
                    }
                    
                }
                .disabled(isSaving)
                .font(.urbanistSemiBold(15))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.cakeBrown)
                .clipShape(Capsule())
                
                Button {
                    Task {
                        await saveDraft()
                    }
                } label: {
                    if isSaving {
                        ProgressView()
                            .tint(Color(red: 0.2, green: 0.2, blue: 0.2))
                    } else {
                        Text("Save As Draft")
                    }
                }
                .disabled(isSaving)
                .font(.urbanistSemiBold(15))
                .foregroundColor(Color(red: 0.2, green: 0.2, blue: 0.2))
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.white)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color(red: 0.80, green: 0.80, blue: 0.80), lineWidth: 1.5)
                )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.white)
            .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: -3)
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showCamera) {
            CameraPickerView(capturedImage: $cameraImage, isPresented: $showCamera)
                .ignoresSafeArea()
        }
        .alert("Success", isPresented: $showSuccessAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(successMessage)
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.3))
                }
            }
            ToolbarItem(placement: .principal) {
                Text("Create Cake Request")
                    .font(.urbanistSemiBold(16))
                    .foregroundColor(.cakeBrown)
            }
        }
        .sheet(isPresented: $showDatePicker) {
            VStack {
                DatePicker("", selection: $expectedDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .tint(.cakeBrown)
                    .padding()
                Button("Done") { showDatePicker = false }
                    .font(.urbanistSemiBold(15))
                    .foregroundColor(.cakeBrown)
                    .padding(.bottom, 20)
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showTimePicker) {
            VStack(spacing: 16) {
                Text("Select Time")
                    .font(.urbanistSemiBold(16))
                    .padding(.top, 20)
                DatePicker("", selection: $expectedTime, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .tint(.cakeBrown)
                    .labelsHidden()
                Button("Done") { showTimePicker = false }
                    .font(.urbanistSemiBold(15))
                    .foregroundColor(.cakeBrown)
                    .padding(.bottom, 20)
            }
            .presentationDetents([.fraction(0.45)])
        }
    }
    
    // MARK: - Save to Firebase
    @MainActor
    private func publishRequest() async {
        isSaving = true
        defer { isSaving = false }
        
        guard let userID = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        let customerProfile = await fetchCurrentUserProfile(from: db, userID: userID)
        
        guard canPublishRequest else {
            await persistRequest(
                in: db,
                collection: "draftRequests",
                documentID: db.collection("draftRequests").document().documentID,
                customerID: userID,
                customerProfile: customerProfile,
                status: "draft",
                timestampField: "savedAt",
                successText: "Incomplete details were saved as a draft idea."
            )
            return
        }
        
        await persistRequest(
            in: db,
            collection: "cakeRequests",
            documentID: db.collection("cakeRequests").document().documentID,
            customerID: userID,
            customerProfile: customerProfile,
            status: "open",
            timestampField: "createdAt",
            successText: "Request published successfully!"
        )
    }
    
    // MARK: - Save as Draft
    @MainActor
    private func saveDraft() async {
        isSaving = true
        defer { isSaving = false }
        
        guard let userID = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        let customerProfile = await fetchCurrentUserProfile(from: db, userID: userID)
        
        await persistRequest(
            in: db,
            collection: "draftRequests",
            documentID: db.collection("draftRequests").document().documentID,
            customerID: userID,
            customerProfile: customerProfile,
            status: "draft",
            timestampField: "savedAt",
            successText: "Draft saved successfully!"
        )
    }
    
    private var canPublishRequest: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !selectedCategories.isEmpty
    }
    
    private func fetchCurrentUserProfile(from db: Firestore, userID: String) async -> [String: Any] {
        do {
            let snapshot = try await db.collection("users").document(userID).getDocument()
            return snapshot.data() ?? [:]
        } catch {
            print("Error fetching current user profile: \(error)")
            return [:]
        }
    }
    
    @MainActor
    private func persistRequest(
        in db: Firestore,
        collection: String,
        documentID: String,
        customerID: String,
        customerProfile: [String: Any],
        status: String,
        timestampField: String,
        successText: String
    ) async {
        let requestData = buildRequestData(
            documentID: documentID,
            customerID: customerID,
            customerProfile: customerProfile,
            status: status,
            timestampField: timestampField
        )
        
        do {
            try await db.collection(collection).document(documentID).setData(requestData, merge: true)
            successMessage = "✓ \(successText)"
            showSuccessAlert = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                dismiss()
            }
        } catch {
            print("Error saving request to \(collection): \(error)")
        }
    }
    
    private func buildRequestData(
        documentID: String,
        customerID: String,
        customerProfile: [String: Any],
        status: String,
        timestampField: String
    ) -> [String: Any] {
        let profileName = (customerProfile["name"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let customerName = profileName.isEmpty ? (Auth.auth().currentUser?.email ?? "Customer") : profileName
        
        var data: [String: Any] = [
            "id": documentID,
            "title": title,
            "description": description,
            "customerID": customerID,
            "customerName": customerName,
            "customerEmail": customerProfile["email"] as? String ?? (Auth.auth().currentUser?.email ?? ""),
            "customerCity": customerProfile["city"] as? String ?? "",
            "customerAddress": customerProfile["address"] as? String ?? "",
            "category": selectedCategories.first ?? "",
            "categories": Array(selectedCategories),
            "styles": Array(selectedStyles),
            "dietary": Array(selectedDietary),
            "tier": selectedTier ?? 0,
            "cakeSize": cakeSize,
            "sugarLevel": sugarLevel,
            "flavours": Array(selectedFlavours),
            "fillingFlavour": fillingFlavour,
            "specialInstructions": specialInstructions,
            "budgetMin": budgetMin,
            "budgetMax": budgetMax,
            "expectedDate": expectedDate.timeIntervalSince1970,
            "expectedTime": expectedTime.timeIntervalSince1970,
            "allowNearby": allowNearby,
            "bidCount": 0,
            "status": status,
            timestampField: Date().timeIntervalSince1970
        ]
        
        if timestampField != "createdAt", data["createdAt"] == nil {
            data["createdAt"] = Date().timeIntervalSince1970
        }
        
        return data
    }
    
    // MARK: - Helpers
    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.urbanistBold(15))
            .foregroundColor(Color(red: 0.15, green: 0.15, blue: 0.15))
            .padding(.horizontal, 16)
            .padding(.bottom, 10)
            .padding(.top, 4)
    }
    
    private func specDivider() -> some View {
        Divider()
            .background(Color(red: 0.92, green: 0.92, blue: 0.92))
    }
    
    @ViewBuilder
    private func fieldBlock<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.urbanistSemiBold(13))
                .foregroundColor(.cakeBrown)
            content()
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(red: 0.85, green: 0.85, blue: 0.85), lineWidth: 1)
                )
        }
    }
    
    
    // MARK: - Budget Range Slider
    struct BudgetRangeSlider: View {
        @Binding var minVal: Double
        @Binding var maxVal: Double
        private let lo: Double = 0
        private let hi: Double = 100000
        
        var body: some View {
            GeometryReader { geo in
                let w = geo.size.width
                let range = hi - lo
                let minX  = CGFloat((minVal - lo) / range) * w
                let maxX  = CGFloat((maxVal - lo) / range) * w
                
                ZStack(alignment: .leading) {
                    // Track
                    Capsule()
                        .fill(Color(red: 0.88, green: 0.88, blue: 0.88))
                        .frame(height: 4)
                    
                    // Selected range
                    Capsule()
                        .fill(Color.cakeBrown)
                        .frame(width: max(0, maxX - minX), height: 4)
                        .offset(x: minX)
                    
                    // Min thumb
                    thumb(at: minX)
                        .gesture(DragGesture(minimumDistance: 0)
                            .onChanged { v in
                                let pct = Double(max(0, min(v.location.x, CGFloat(maxX - 20))) / w)
                                minVal = max(lo, min(pct * range + lo, maxVal - 1000))
                            })
                    
                    // Max thumb
                    thumb(at: maxX)
                        .gesture(DragGesture(minimumDistance: 0)
                            .onChanged { v in
                                let pct = Double(max(CGFloat(minX + 20), min(v.location.x, w)) / w)
                                maxVal = min(hi, max(pct * range + lo, minVal + 1000))
                            })
                }
            }
            .frame(height: 22)
        }
        
        private func thumb(at x: CGFloat) -> some View {
            Circle()
                .fill(Color.cakeBrown)
                .frame(width: 22, height: 22)
                .offset(x: x - 11)
        }
    }
    
    // MARK: - Chip Selector
    struct ChipSelector: View {
        let title: String
        let helpText: String
        @Binding var options: [String]
        @Binding var selected: Set<String>
        var showAddButton: Bool = true
        
        @State private var showAddAlert = false
        @State private var newItemText  = ""
        
        var body: some View {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 4) {
                    Text(title)
                        .font(.urbanistSemiBold(14))
                        .foregroundColor(.cakeBrown)
                    Text("( \(helpText) )")
                        .font(.urbanistRegular(12))
                        .foregroundColor(.cakeGrey)
                    Spacer()
                    if showAddButton {
                        Button { showAddAlert = true } label: {
                            Image(systemName: "plus.circle")
                                .font(.system(size: 17))
                                .foregroundColor(.cakeBrown)
                        }
                    }
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(options, id: \.self) { opt in
                            Button {
                                if selected.contains(opt) { selected.remove(opt) }
                                else { selected.insert(opt) }
                            } label: {
                                Text(opt)
                                    .font(.urbanistRegular(13))
                                    .foregroundColor(selected.contains(opt) ? .white : Color(red: 0.2, green: 0.2, blue: 0.2))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 7)
                                    .background(selected.contains(opt) ? Color.cakeBrown : Color.white)
                                    .cornerRadius(20)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20)
                                            .stroke(Color(red: 0.82, green: 0.82, blue: 0.82), lineWidth: 1)
                                    )
                            }
                        }
                    }
                }
            }
            .alert("Add \(title)", isPresented: $showAddAlert) {
                TextField("Enter name", text: $newItemText)
                Button("Add") {
                    let trimmed = newItemText.trimmingCharacters(in: .whitespaces)
                    if !trimmed.isEmpty && !options.contains(trimmed) {
                        options.append(trimmed)
                        selected.insert(trimmed)
                    }
                    newItemText = ""
                }
                Button("Cancel", role: .cancel) { newItemText = "" }
            } message: {
                Text("Enter a custom \(title.lowercased()) option")
            }
        }
    }
    
    // MARK: - Image Picker Button
    struct ImagePickerButton: View {
        let icon: String
        let label: String
        
        var body: some View {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(Color(red: 0.4, green: 0.4, blue: 0.4))
                Text(label)
                    .font(.urbanistRegular(12))
                    .foregroundColor(Color(red: 0.4, green: 0.4, blue: 0.4))
            }
            .frame(width: 90, height: 72)
            .background(Color(red: 0.96, green: 0.96, blue: 0.96))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(red: 0.85, green: 0.85, blue: 0.85), lineWidth: 1)
            )
        }
    }
}

struct CreateCakeRequestView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            CreateCakeRequestView()
        }
    }
}
