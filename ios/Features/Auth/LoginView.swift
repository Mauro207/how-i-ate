import SwiftUI

struct LoginView: View {
    @StateObject var viewModel: LoginViewModel
    @State private var showPassword = false
    @FocusState private var focusedField: Field?

    private enum Field {
        case email
        case password
    }

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundView

                ScrollView {
                    VStack(spacing: 26) {
                        headerView
                            .padding(.top, 42)

                        glassCard {
                            VStack(spacing: 18) {
                                inputGroup(title: "Indirizzo email", icon: "envelope") {
                                    TextField("Inserisci l'email", text: $viewModel.email)
                                        .keyboardType(.emailAddress)
                                        .textInputAutocapitalization(.never)
                                        .autocorrectionDisabled()
                                        .textContentType(.username)
                                        .submitLabel(.next)
                                        .focused($focusedField, equals: .email)
                                        .onSubmit { focusedField = .password }
                                }

                                inputGroup(title: "Password", icon: "lock") {
                                    HStack(spacing: 10) {
                                        Group {
                                            if showPassword {
                                                TextField("Inserisci la password", text: $viewModel.password)
                                            } else {
                                                SecureField("Inserisci la password", text: $viewModel.password)
                                            }
                                        }
                                        .textContentType(.password)
                                        .submitLabel(.go)
                                        .focused($focusedField, equals: .password)
                                        .onSubmit {
                                            Task { await viewModel.login() }
                                        }

                                        Button {
                                            showPassword.toggle()
                                        } label: {
                                            Image(systemName: showPassword ? "eye.slash" : "eye")
                                                .font(.body.weight(.semibold))
                                                .foregroundStyle(.secondary)
                                                .frame(width: 32, height: 32)
                                        }
                                        .buttonStyle(.plain)
                                        .accessibilityLabel(showPassword ? "Nascondi password" : "Mostra password")
                                    }
                                }

                                if let errorMessage = viewModel.errorMessage {
                                    errorBanner(errorMessage)
                                }

                                loginButton

                                Text("Non hai un account? Chiedi a Mauro")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .center)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 28)
                    .frame(maxWidth: 520)
                    .frame(maxWidth: .infinity)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var backgroundView: some View {
        LinearGradient(
            colors: [
                Color(uiColor: .systemGroupedBackground),
                Color.indigo.opacity(0.14),
                Color(uiColor: .secondarySystemGroupedBackground)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var headerView: some View {
        VStack(spacing: 14) {
            Image(systemName: "fork.knife.circle.fill")
                .font(.system(size: 58, weight: .semibold))
                .foregroundStyle(Color.indigo)
                .symbolRenderingMode(.hierarchical)

            VStack(spacing: 6) {
                Text("How I Ate")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)

                Text("Accedi al tuo account")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func glassCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        if #available(iOS 26.0, *) {
            content()
                .padding(22)
                .glassEffect(.regular.tint(.indigo.opacity(0.08)), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        } else {
            content()
                .padding(22)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.primary.opacity(0.07), lineWidth: 1)
                }
        }
    }

    private func inputGroup<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)

            inputField(content: content)
        }
    }

    @ViewBuilder
    private func inputField<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)

        HStack {
            content()
        }
        .padding(.horizontal, 16)
        .frame(height: 54)
        .background(Color(uiColor: .secondarySystemGroupedBackground).opacity(0.64), in: shape)
        .overlay {
            shape.stroke(Color.primary.opacity(0.08), lineWidth: 1)
        }
    }

    @ViewBuilder
    private var loginButton: some View {
        Button {
            Task { await viewModel.login() }
        } label: {
            HStack(spacing: 8) {
                if viewModel.isLoading {
                    ProgressView()
                        .tint(.white)
                }
                Text(viewModel.isLoading ? "Accesso in corso..." : "Accedi")
                    .fontWeight(.semibold)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!viewModel.canSubmit)
        .opacity(viewModel.canSubmit ? 1 : 0.55)
        .accessibilityHint(viewModel.canSubmit ? "Esegue l'accesso" : "Inserisci email e password")
        .modifier(PrimaryGlassButtonModifier())
    }

    @ViewBuilder
    private func errorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.footnote.weight(.semibold))
            Text(message)
                .font(.footnote)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(.red)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.red.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct PrimaryGlassButtonModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular.tint(.indigo).interactive(), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        } else {
            content
                .background(Color.indigo, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }
}
