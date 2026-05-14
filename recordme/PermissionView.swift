import SwiftUI

struct PermissionView: View {
    @ObservedObject var permissionManager: ScreenRecordingPermissionManager

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "display.trianglebadge.exclamationmark")
                    .font(.system(size: 64, weight: .thin))
                    .foregroundColor(.orange)

                VStack(spacing: 8) {
                    Text("Screen Recording Permission Required")
                        .font(.system(.title, design: .rounded, weight: .semibold))
                        .foregroundColor(.primary)

                    VStack(spacing: 8) {
                        Text("RecordMe needs permission to record your screen to capture displays and windows.")
                            .font(.system(.body, design: .rounded))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 400)

                        if permissionManager.authorizationStatus == .denied {
                            Text("Permission was previously denied. Click 'Grant Permission' to try again, or use 'Open System Preferences' to enable manually.")
                                .font(.system(.caption, design: .rounded))
                                .foregroundColor(.orange)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: 400)
                                .padding(.top, 4)
                        }
                    }
                }
            }

            VStack(spacing: 12) {
                if permissionManager.authorizationStatus == .checking {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Checking permissions...")
                            .font(.system(.callout, design: .rounded))
                    }
                    .padding(.vertical, 8)
                } else {
                    Button {
                        Task {
                            await permissionManager.requestPermission()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.shield")
                                .font(.system(size: 14, weight: .medium))
                            Text("Grant Permission")
                                .font(.system(.callout, design: .rounded, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.blue)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button {
                        permissionManager.checkAuthorizationStatus()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 14, weight: .medium))
                            Text("Refresh Status")
                                .font(.system(.callout, design: .rounded, weight: .medium))
                        }
                        .foregroundColor(.primary)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color(.controlBackgroundColor))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .strokeBorder(Color(.separatorColor), lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Check if permissions are already granted")

                    if permissionManager.authorizationStatus == .denied {
                        Button {
                            permissionManager.openSystemPreferences()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "gear")
                                    .font(.system(size: 14, weight: .medium))
                                Text("Open System Preferences")
                                    .font(.system(.callout, design: .rounded, weight: .medium))
                            }
                            .foregroundColor(.primary)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color(.controlBackgroundColor))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .strokeBorder(Color(.separatorColor), lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help("Open Privacy & Security settings to manually enable screen recording")
                    }
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.windowBackgroundColor))
    }
}
