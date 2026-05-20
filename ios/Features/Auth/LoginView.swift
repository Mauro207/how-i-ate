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
                LinearGradient(
                    colors: [Color.indigo.opacity(0.2), Color.blue.opacity(0.12), Color.clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 18) {
                    VStack(spacing: 6) {
                        Text("How I Ate")
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                        Text("Accedi al tuo account")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 24)

                    VStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Indirizzo email")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.secondary)

                            TextField("Inserisci l'email", text: $viewModel.email)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .textContentType(.username)
                                .submitLabel(.next)
                                .focused($focusedField, equals: .email)
                                .onSubmit { focusedField = .password }
                                .padding(.horizontal, 14)
                                .frame(height: 52)
                                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Password")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.secondary)

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
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 14)
                            .frame(height: 52)
                            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }

                        if let errorMessage = viewModel.errorMessage {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                Text(errorMessage)
                                    .font(.footnote)
                            }
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }

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
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.indigo)
                        .disabled(!viewModel.canSubmit)

                        Text("Non hai un account? Chiedi a Mauro")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .padding(20)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}
