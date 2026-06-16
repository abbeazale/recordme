import SwiftUI

/// Shown until screen-recording permission is granted. Uses native buttons and
/// surfaces the denied state with a clear path to System Settings.
struct PermissionView: View {
    @ObservedObject var permissionManager: ScreenRecordingPermissionManager

    private var isDenied: Bool { permissionManager.authorizationStatus == .denied }
    private var isChecking: Bool { permissionManager.authorizationStatus == .checking }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "rectangle.dashed.badge.record")
                .font(.system(size: 56, weight: .regular))
                .foregroundStyle(.tint)
                .symbolRenderingMode(.hierarchical)

            VStack(spacing: 8) {
                Text("Screen Recording Access Needed")
                    .font(.title2.weight(.semibold))

                Text("RecordMe needs permission to capture your displays and windows. Your recordings stay on this Mac.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)

                if isDenied {
                    Text("Permission was previously denied. Enable RecordMe under Privacy & Security → Screen Recording, then return here.")
                        .font(.callout)
                        .foregroundStyle(.orange)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 420)
                        .padding(.top, 2)
                }
            }

            if isChecking {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Checking permissions…").foregroundStyle(.secondary)
                }
                .padding(.top, 4)
            } else {
                VStack(spacing: 10) {
                    Button {
                        Task { await permissionManager.requestPermission() }
                    } label: {
                        Label("Grant Permission", systemImage: "checkmark.shield.fill")
                            .frame(minWidth: 200)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    if isDenied {
                        Button {
                            permissionManager.openSystemPreferences()
                        } label: {
                            Label("Open System Settings", systemImage: "gearshape")
                                .frame(minWidth: 200)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    }

                    Button("Refresh Status") {
                        permissionManager.checkAuthorizationStatus()
                    }
                    .buttonStyle(.link)
                    .help("Check if permissions are already granted")
                }
                .padding(.top, 4)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
        .background(Color(.windowBackgroundColor))
    }
}
