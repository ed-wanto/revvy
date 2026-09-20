import SwiftUI

struct ConnectView: View {
    @Environment(AppModel.self) private var model
    @State private var manualToken = ""
    @State private var showManualToken = false
    @State private var isImporting = false

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 34, weight: .light))
                    .foregroundStyle(RevvyStyle.accent)
                Text("GitHub と連携")
                    .font(.system(size: 20, weight: .semibold))
                Text("共有リンクの作成と Issue の登録に使います。\n撮影・編集・保存は連携なしで利用できます。")
                    .font(.system(size: 12))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }

            if case .awaitingDeviceApproval(let code, let uri) = model.auth {
                deviceApproval(code: code, uri: uri)
            } else {
                connectOptions
            }

            if let error = model.authError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 480)
            }
        }
        .padding(.horizontal, 40)
        .padding(.bottom, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var connectOptions: some View {
        let hasClientID = !model.clientID.isEmpty
        return VStack(spacing: 12) {
            Button {
                model.startDeviceFlow()
            } label: {
                Label("GitHub と連携", systemImage: "link")
                    .frame(maxWidth: 320)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            .disabled(!hasClientID)

            Text(hasClientID
                 ? "ブラウザが開くので、表示されたコードを入力して承認してください。"
                 : "OAuth App の Client ID が設定されていません。設定画面で入力してください。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)

            DisclosureGroup("開発者向け: 別の方法で連携", isExpanded: $showManualToken) {
                VStack(spacing: 10) {
                    if GHCLITokenImporter.installedPath != nil {
                        Button {
                            isImporting = true
                            Task {
                                await model.importTokenFromGHCLI()
                                isImporting = false
                            }
                        } label: {
                            Label(isImporting ? "取り込み中…" : "gh CLI のログインを使う", systemImage: "terminal")
                                .frame(maxWidth: .infinity)
                        }
                        .disabled(isImporting)
                    }
                    HStack {
                        SecureField("ghp_… / github_pat_…（repo スコープ）", text: $manualToken)
                            .textFieldStyle(.roundedBorder)
                        Button("連携") {
                            Task { await model.signIn(token: manualToken) }
                        }
                        .disabled(manualToken.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                .padding(.top, 8)
            }
            .frame(maxWidth: 320)
            .font(.callout)
        }
    }

    private func deviceApproval(code: String, uri: URL) -> some View {
        VStack(spacing: 16) {
            Text("ブラウザで下のコードを入力して承認してください")
                .font(.headline)
            Text(code)
                .font(.system(size: 36, weight: .bold, design: .monospaced))
                .tracking(4)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
                .textSelection(.enabled)
            Text("コードはクリップボードにコピー済みです")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Link("ブラウザを開く", destination: uri)
                    .buttonStyle(.bordered)
                Button("キャンセル") { model.cancelDeviceFlow() }
            }
            ProgressView()
                .controlSize(.small)
        }
    }
}
