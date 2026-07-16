import SwiftUI
import CampingCore

/// 메인 윈도우: 요약 + 캘린더 진입.
struct ContentView: View {
    @ObservedObject var viewModel: ReservationViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(viewModel.snapshot.campground.displayName)
                    .font(.largeTitle).bold()
                Spacer()
                if viewModel.isLoading { ProgressView() }
                Button {
                    Task { await viewModel.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }

            ForEach(viewModel.displayedSnapshot.months) { month in
                GroupBox(month.label) {
                    CalendarView(month: month)
                }
            }

            Text("마지막 갱신: \(viewModel.snapshot.generatedAt.formatted(date: .abbreviated, time: .shortened))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(minWidth: 420, minHeight: 360)
    }
}
