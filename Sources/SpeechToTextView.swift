import SwiftUI

struct SpeechToTextView: View {
  @State private var viewModel = SpeechViewModel()

  var body: some View {
    NavigationStack {
      VStack(spacing: 0) {
        ScrollView {
          Text(viewModel.transcribedText)
            .font(.system(size: 30))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .frame(maxHeight: .infinity)

        if let error = viewModel.errorMessage {
          Text(error)
            .foregroundStyle(.red)
            .padding()
        }

        if viewModel.permissionGranted {
          Button(action: viewModel.toggleRecording) {
            Label(
              viewModel.isRecording ? "Stop" : "Record",
              systemImage: viewModel.isRecording ? "stop.fill" : "mic"
            )
            .frame(maxWidth: .infinity)
            .padding()
            .background(viewModel.isRecording ? Color.red : Color(.darkGray))
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 15))
          }
          .padding(.horizontal, 40)
          .padding(.bottom, 50)
        } else {
          Text("Microphone permission is required to use this app.")
            .foregroundStyle(.secondary)
            .padding()
        }
      }
      .navigationTitle("gRPC Speech To Text")
      .toolbarTitleDisplayMode(.inline)
    }
    .preferredColorScheme(.dark)
    .task {
      await viewModel.requestPermission()
    }
  }
}

#Preview {
  SpeechToTextView()
}
