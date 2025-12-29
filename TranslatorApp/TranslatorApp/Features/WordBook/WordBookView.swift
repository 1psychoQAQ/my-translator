import SwiftUI

struct WordBookView: View {

    @StateObject private var viewModel: WordBookViewModel

    init(viewModel: WordBookViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            VStack {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = viewModel.errorMessage {
                    errorView(message: error)
                } else if viewModel.words.isEmpty {
                    emptyStateView
                } else {
                    wordListView
                }
            }
            .searchable(text: $viewModel.searchText, prompt: "搜索单词")
            .onChange(of: viewModel.searchText) { _, _ in
                viewModel.loadWords()
            }
            .navigationTitle("单词本")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { viewModel.loadWords() }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .help("刷新")
                }
            }
        }
        .onAppear {
            viewModel.loadWords()
        }
    }

    private var wordListView: some View {
        List {
            ForEach(viewModel.words, id: \.id) { word in
                WordRowView(word: word)
            }
            .onDelete(perform: viewModel.deleteWords)
        }
        .listStyle(.inset)
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "book.closed")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text(viewModel.searchText.isEmpty ? "单词本为空" : "未找到匹配的单词")
                .font(.title3)
                .foregroundColor(.secondary)

            if viewModel.searchText.isEmpty {
                Text("使用截图翻译功能收藏单词")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)

            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button("重试") {
                viewModel.loadWords()
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - WordRowView

struct WordRowView: View {
    let word: Word

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(word.text)
                .font(.headline)
                .lineLimit(2)

            Text(word.translation)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)

            HStack {
                Label(word.source, systemImage: sourceIcon)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Text(word.createdAt, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
        .textSelection(.enabled)
    }

    private var sourceIcon: String {
        switch word.source {
        case "screenshot": return "camera.viewfinder"
        case "webpage": return "globe"
        case "video": return "play.rectangle"
        default: return "doc.text"
        }
    }
}
