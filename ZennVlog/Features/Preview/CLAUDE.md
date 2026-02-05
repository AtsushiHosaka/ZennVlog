# Preview Feature

## 概要
全素材が揃った後、テロップやBGMを追加して最終調整する画面。

## 状態（ViewModel）

| プロパティ | 型 | 説明 |
|-----------|-----|------|
| project | Project | 現在のプロジェクト |
| isPlaying | Bool | 再生中フラグ |
| currentTime | Double | 現在の再生位置（秒） |
| duration | Double | 動画の総時間（秒） |
| currentSegmentIndex | Int | 現在のセグメントインデックス |
| subtitleText | String | 編集中のテロップテキスト |
| selectedBGM | BGMTrack? | 選択中のBGM |
| bgmVolume | Float | BGM音量（0.0 - 1.0、デフォルト0.3） |
| bgmTracks | [BGMTrack] | BGM一覧 |
| showBGMSelector | Bool | BGM選択モーダル表示フラグ |
| isExporting | Bool | 書き出し中フラグ |
| exportProgress | Double | 書き出し進捗（0.0 - 1.0） |
| errorMessage | String? | エラーメッセージ |

## ユーザーアクション

1. **再生/一時停止ボタン** → 動画の再生制御
2. **タイムラインのセグメントをタップ** → そのセグメントにシーク
3. **テロップ入力** → 選択中セグメントにテロップを設定
4. **BGM[変更]ボタン** → BGM選択モーダルを表示
5. **BGM選択** → BGMを変更
6. **[<]ボタン** → 撮影画面に戻る
7. **[共有]ボタン** → シェア画面へ遷移

## 遷移先

- RecordingView（戻る）
- ShareView（共有ボタン）

## UseCase

- `FetchBGMTracksUseCase` - FirestoreからBGM一覧を取得（MockBGMRepositoryで5曲提供）
- `SaveSubtitleUseCase` - テロップをSwiftDataに保存
- `DownloadBGMUseCase` - BGMをダウンロードしローカルキャッシュ
- `ExportVideoUseCase` - NextLevelSessionExporterで動画 + テロップ + BGMを合成して書き出し

## コンポーネント

- `VideoPlayerView` - 動画プレーヤー（テロップオーバーレイ付き）
- `SubtitleOverlay` - テロップ表示レイヤー
- `SubtitleEditor` - テロップ入力欄
- `BGMSelector` - BGM選択モーダル（試聴機能付き）
- `PreviewTimeline` - セグメント選択用タイムライン

## 注意点

- テロップはセグメントごとに設定
- BGMはチャット時点で選択済みだが、ここで変更可能、音量調整も可能
- 書き出しはNextLevelSessionExporterを使用（AVAssetExportSessionより高機能）
- 書き出し完了後にShareViewへ遷移
- **タイムラインは読み取り専用**：Recording画面と異なり、動画の追加・削除・並び替えは不可、シーク機能のみ
- AVPlayerでセグメントを結合して再生、Time Observerでテロップ同期
- 大きな動画ファイルはメモリ最適化が必要
- 書き出しには一時ストレージ（動画サイズx2）が必要

---

## UI/UX詳細設計

### 画面レイアウト
```
VStack {
    // 上部: 動画プレーヤー（テロップオーバーレイ付き）
    ZStack {
        VideoPlayerView(player: player)
            .aspectRatio(16/9, contentMode: .fit)

        SubtitleOverlay(subtitle: currentSubtitle)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }

    // 中央: タイムライン（読み取り専用、シーク機能のみ）
    PreviewTimeline(
        segments: segments,
        currentTime: currentTime,
        onSegmentTap: { segmentIndex in
            seekToSegment(segmentIndex)  // 再生位置移動のみ（編集不可）
        }
    )
    .frame(height: 80)

    // 下部: コントロールエリア
    HStack {
        // 再生/一時停止ボタン
        Button(action: togglePlayPause) {
            Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                .font(.largeTitle)
        }

        // 時間表示
        Text(formatTime(currentTime))
        Slider(value: $currentTime, in: 0...duration)
        Text(formatTime(duration))
    }

    // テロップ編集エリア
    VStack(alignment: .leading) {
        Text("セグメント \(currentSegmentIndex + 1) のテロップ")
            .font(.headline)
        TextField("テロップを入力", text: $subtitleText)
            .textFieldStyle(.roundedBorder)
        Button("保存") {
            saveSubtitle()
        }
    }

    // BGMコントロール
    HStack {
        Text("BGM: \(selectedBGM?.title ?? "未選択")")
        Button("変更") {
            showBGMSelector = true
        }
        Slider(value: $bgmVolume, in: 0...1)
        Text("\(Int(bgmVolume * 100))%")
    }

    // 書き出しボタン
    Button("書き出して共有") {
        exportVideo()
    }
    .disabled(isExporting)
    if isExporting {
        ProgressView(value: exportProgress)
        Text("\(Int(exportProgress * 100))%")
    }
}
```

### VideoPlayerView詳細
- AVPlayerをSwiftUIでラップ
- AVPlayerLayer使用
- アスペクト比16:9固定
- タップで再生/一時停止
- ダブルタップでフルスクリーン（将来的）

### SubtitleOverlay詳細
- テキスト表示レイヤー
- 下部中央配置
- 黒背景（半透明）+ 白文字
- 改行対応
- フォント: システムフォント Bold 18pt
- パディング: 上下8pt、左右12pt

### PreviewTimeline詳細
- **読み取り専用**（編集不可、Recording画面との違い）
- 横スクロール可能
- セグメントカード表示（幅は動画長に比例）
- 現在の再生位置を示す縦線インジケータ
- **セグメントタップでシーク機能のみ**（動画追加・削除・並び替えは不可）
- テロップ設定済みセグメントには✓マーク表示
- **注意**: Recording画面のタイムラインは編集可能（動画追加・削除・ストック管理）、Preview画面は再生位置移動のみ

### BGMSelector詳細（モーダル）
- Sheet形式で表示
- BGMTrack一覧をList表示
- 各トラック: タイトル、ジャンル、試聴ボタン
- タップで選択、自動的にダウンロード
- キャンセルボタンで閉じる

---

## データフロー

```
Recording → 全素材撮影完了 → [編集]ボタン → Preview遷移
  ↓
PreviewViewModel.init(project: Project)
  ↓
Project.videoAssetsから動画読み込み → AVPlayer作成 → duration計算
  ↓
FetchBGMTracksUseCase → bgmTracks取得
  ↓
Project.subtitles → 既存テロップ復元
  ↓
ユーザーが再生/編集
  ↓
テロップ編集 → SaveSubtitleUseCase → Project.subtitles更新 → SwiftData保存
  ↓
BGM選択 → DownloadBGMUseCase → ローカルキャッシュ → Project.selectedBGMId更新
  ↓
[書き出して共有]ボタン → ExportVideoUseCase実行
  ↓
NextLevelSessionExporter:
  1. videoAssets結合（セグメント順）
  2. SubtitleをCATextLayerでオーバーレイ
  3. BGMをオーディオトラックとしてミックス
  4. H.264エンコード、1920x1080、6Mbps
  ↓
書き出し完了 → exportedVideoURL取得 → Share画面へ遷移
```

---

## 状態管理とロジック

### PreviewViewModel設計
```swift
@MainActor
final class PreviewViewModel: ObservableObject {
    // Dependencies
    private let exportVideoUseCase: ExportVideoUseCaseProtocol
    private let fetchBGMTracksUseCase: FetchBGMTracksUseCaseProtocol
    private let saveSubtitleUseCase: SaveSubtitleUseCaseProtocol
    private let downloadBGMUseCase: DownloadBGMUseCaseProtocol

    // State
    @Published var project: Project
    @Published var isPlaying: Bool = false
    @Published var currentTime: Double = 0.0
    @Published var duration: Double = 0.0
    @Published var currentSegmentIndex: Int = 0
    @Published var subtitleText: String = ""
    @Published var selectedBGM: BGMTrack?
    @Published var bgmVolume: Float = 0.3
    @Published var bgmTracks: [BGMTrack] = []
    @Published var showBGMSelector: Bool = false
    @Published var isExporting: Bool = false
    @Published var exportProgress: Double = 0.0
    @Published var errorMessage: String?

    private var player: AVPlayer?
    private var timeObserver: Any?

    // Computed
    var currentSubtitle: Subtitle? {
        project.subtitles.first { $0.segmentOrder == currentSegmentIndex }
    }

    var segments: [Segment] {
        project.template?.segments ?? []
    }
}
```

### セグメント管理
```swift
func updateCurrentSegment(time: Double) {
    guard let segments = project.template?.segments else { return }

    if let index = segments.firstIndex(where: {
        $0.startSeconds <= time && time < $0.endSeconds
    }) {
        currentSegmentIndex = index
        // テロップテキストを復元
        if let subtitle = currentSubtitle {
            subtitleText = subtitle.text
        } else {
            subtitleText = ""
        }
    }
}
```

### テロップ管理
```swift
func saveSubtitle() async {
    do {
        try await saveSubtitleUseCase.execute(
            project: project,
            segmentOrder: currentSegmentIndex,
            text: subtitleText
        )
    } catch {
        errorMessage = "テロップの保存に失敗しました"
    }
}
```

---

## 動画再生ロジック（AVPlayer）

### AVPlayer設定
```swift
func loadProject() async {
    // 1. videoAssetsを結合してAVCompositionを作成
    let composition = AVMutableComposition()
    let videoTrack = composition.addMutableTrack(
        withMediaType: .video,
        preferredTrackID: kCMPersistentTrackID_Invalid
    )

    var currentTime = CMTime.zero

    // セグメント順にvideoAssetsを結合
    for segment in segments {
        guard let asset = project.videoAssets.first(where: { $0.segmentOrder == segment.order }) else {
            continue
        }

        let url = URL(fileURLWithPath: asset.localFileURL)
        let avAsset = AVURLAsset(url: url)
        let assetTrack = try? await avAsset.loadTracks(withMediaType: .video).first

        guard let assetTrack = assetTrack else { continue }

        let timeRange = CMTimeRange(
            start: .zero,
            duration: avAsset.duration
        )

        try? videoTrack?.insertTimeRange(
            timeRange,
            of: assetTrack,
            at: currentTime
        )

        currentTime = CMTimeAdd(currentTime, avAsset.duration)
    }

    // 2. AVPlayerを作成
    let playerItem = AVPlayerItem(asset: composition)
    player = AVPlayer(playerItem: playerItem)
    duration = CMTimeGetSeconds(composition.duration)

    // 3. Time Observerを設定（0.1秒間隔）
    let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
    timeObserver = player?.addPeriodicTimeObserver(
        forInterval: interval,
        queue: .main
    ) { [weak self] time in
        self?.currentTime = CMTimeGetSeconds(time)
        self?.updateCurrentSegment(time: self?.currentTime ?? 0)
    }

    // 4. BGM読み込み
    await loadBGMTracks()
}
```

### テロップ同期
Time Observerで0.1秒ごとにcurrentTimeを更新し、現在のセグメントを判定してテロップを切り替える。

```swift
func updateCurrentSegment(time: Double) {
    guard let segments = project.template?.segments else { return }

    if let index = segments.firstIndex(where: {
        $0.startSeconds <= time && time < $0.endSeconds
    }) {
        if currentSegmentIndex != index {
            currentSegmentIndex = index
            // テロップテキストを更新
            if let subtitle = currentSubtitle {
                subtitleText = subtitle.text
            } else {
                subtitleText = ""
            }
        }
    }
}
```

---

## BGM管理詳細

### BGM選択・試聴
```swift
func loadBGMTracks() async {
    do {
        bgmTracks = try await fetchBGMTracksUseCase.execute()

        // 既存のBGM選択を復元
        if let bgmId = project.selectedBGMId {
            selectedBGM = bgmTracks.first { $0.id == bgmId }
        }
    } catch {
        errorMessage = "BGM一覧の取得に失敗しました"
    }
}

func selectBGM(_ track: BGMTrack) async {
    do {
        // BGMをダウンロード（キャッシュ）
        let url = try await downloadBGMUseCase.execute(track: track)
        selectedBGM = track

        // Projectに保存
        project.selectedBGMId = track.id

        showBGMSelector = false
    } catch {
        errorMessage = "BGMのダウンロードに失敗しました"
    }
}

func previewBGM(_ track: BGMTrack) async {
    // 試聴用AVPlayer（15秒のみ再生）
    // 実装詳細は省略
}
```

### 音量調整
```swift
@Published var bgmVolume: Float = 0.3  // 0.0 - 1.0

// Slider UI
Slider(value: $bgmVolume, in: 0...1)
    .onChange(of: bgmVolume) { newValue in
        // リアルタイムプレビュー（将来的）
    }
```

---

## 動画合成・書き出しロジック（NextLevelSessionExporter）

### ExportVideoUseCase仕様
```swift
protocol ExportVideoUseCaseProtocol {
    func execute(
        project: Project,
        bgmTrack: BGMTrack?,
        bgmVolume: Float,
        progressHandler: @escaping (Double) -> Void
    ) async throws -> URL
}
```

### NextLevelSessionExporter使用方法
```swift
func exportVideo() async {
    isExporting = true
    exportProgress = 0.0

    do {
        let exportedURL = try await exportVideoUseCase.execute(
            project: project,
            bgmTrack: selectedBGM,
            bgmVolume: bgmVolume,
            progressHandler: { progress in
                exportProgress = progress
            }
        )

        // Share画面へ遷移
        navigateToShare(exportedURL: exportedURL)

    } catch {
        errorMessage = "動画の書き出しに失敗しました"
    }

    isExporting = false
}
```

### 合成手順（ExportVideoUseCase内部）
```swift
// 1. AVCompositionを作成（videoAssets結合）
let composition = AVMutableComposition()

// 2. ビデオトラック追加
let videoTrack = composition.addMutableTrack(...)
for videoAsset in project.videoAssets.sorted(by: { $0.segmentOrder < $1.segmentOrder }) {
    // videoAssetを順番に結合
}

// 3. オーディオトラック追加（元の動画音声、音量0.7）
let audioTrack = composition.addMutableTrack(...)

// 4. BGMトラック追加（音量: bgmVolume）
if let bgmTrack = bgmTrack {
    let bgmAudioTrack = composition.addMutableTrack(...)
    // フェードイン/アウト設定
}

// 5. テロップオーバーレイ（CATextLayer）
let videoComposition = AVMutableVideoComposition()
for subtitle in project.subtitles {
    let textLayer = CATextLayer()
    textLayer.string = subtitle.text
    textLayer.fontSize = 18
    textLayer.foregroundColor = UIColor.white.cgColor
    textLayer.backgroundColor = UIColor.black.withAlphaComponent(0.7).cgColor
    // segmentのstartSeconds - endSecondsの範囲で表示
}

// 6. NextLevelSessionExporterで書き出し
let exporter = NextLevelSessionExporter(withAsset: composition)
exporter.outputFileType = .mp4
exporter.videoOutputConfiguration = [
    AVVideoCodecKey: AVVideoCodecType.h264,
    AVVideoWidthKey: 1920,
    AVVideoHeightKey: 1080,
    AVVideoCompressionPropertiesKey: [
        AVVideoAverageBitRateKey: 6_000_000
    ]
]
exporter.videoComposition = videoComposition

// 進捗トラッキング
exporter.progressHandler = { progress in
    progressHandler(progress)
}

try await exporter.export()

return exporter.outputURL
```

---

## タイムライン仕様

**重要**: Preview画面のタイムラインは**読み取り専用**です。Recording画面のタイムラインとは異なり、動画の追加・削除・並び替えはできません。シーク機能（再生位置移動）のみ提供します。

### Recording vs Preview タイムラインの違い

| 機能 | Recording画面 | Preview画面 |
|------|--------------|-------------|
| 動画追加 | ✅ 可能 | ❌ 不可 |
| 動画削除 | ✅ 可能 | ❌ 不可 |
| ストック管理 | ✅ 可能 | ❌ 不可 |
| シーク | - | ✅ 可能 |
| 再生位置表示 | - | ✅ 表示 |
| セグメント幅 | 比例表示 | 比例表示 |

### セグメント表示（読み取り専用）
```swift
struct PreviewTimeline: View {
    let segments: [Segment]
    let currentTime: Double
    let onSegmentTap: (Int) -> Void  // シーク機能のみ

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            ZStack(alignment: .leading) {
                // セグメントカード（読み取り専用）
                HStack(spacing: 4) {
                    ForEach(segments) { segment in
                        SegmentCard(segment: segment)
                            .frame(width: segmentWidth(for: segment))
                            .onTapGesture {
                                // シーク機能のみ（編集不可）
                                onSegmentTap(segment.order)
                            }
                            // 長押しメニュー、コンテキストメニューなし（編集不可）
                    }
                }

                // 再生位置インジケータ（縦線）
                Rectangle()
                    .fill(Color.red)
                    .frame(width: 2)
                    .offset(x: offsetForTime(currentTime))
            }
        }
    }

    func segmentWidth(for segment: Segment) -> CGFloat {
        let totalDuration = segments.reduce(0.0) { $0 + ($1.endSeconds - $1.startSeconds) }
        let segmentDuration = segment.endSeconds - segment.startSeconds
        return CGFloat(segmentDuration / totalDuration) * 300
    }

    func offsetForTime(_ time: Double) -> CGFloat {
        // currentTimeからX座標を計算してインジケータ位置を決定
        let totalDuration = segments.reduce(0.0) { $0 + ($1.endSeconds - $1.startSeconds) }
        let totalWidth: CGFloat = 300 * CGFloat(segments.count)
        return CGFloat(currentTime / totalDuration) * totalWidth
    }
}
```

---

## エラーハンドリング詳細

### VideoPlaybackError
- `assetLoadFailed`: 動画ファイルが見つからない/破損
- `playbackFailed`: AVPlayer再生エラー
- `invalidVideoFormat`: サポートされていないコーデック

**対応**: エラーメッセージ表示、Recording画面に戻る

### SubtitleError
- `saveFailed`: SwiftData保存失敗
- `invalidSegmentOrder`: 存在しないセグメント

**対応**: エラーメッセージ表示、再試行ボタン

### BGMError
- `downloadFailed`: ネットワークエラー、Firebase Storageエラー
- `audioMixingFailed`: オーディオミックス失敗
- `invalidTrack`: BGMトラックが見つからない

**対応**: エラーメッセージ表示、BGMなしで書き出し可能にする

### ExportError
- `compositionFailed`: NextLevelSessionExporterエラー
- `insufficientStorage`: ストレージ容量不足
- `cancelled`: ユーザーがキャンセル
- `encodingFailed`: エンコードエラー

**対応**: エラーメッセージ表示、再試行ボタン、ストレージ容量確認

---

## 技術制約と要件

- **AVFoundation**: AVPlayer, AVAsset, AVComposition, AVMutableComposition
- **NextLevelSessionExporter**: Pod依存（Podfileに追加必要）
- **iOS 17+**: モダンSwiftUI機能
- **ストレージ**: 書き出しには一時ストレージ（動画サイズx2）が必要
- **Concurrency**: すべてのUseCaseはasync/awaitを使用
- **メモリ**: 大きな動画ファイルはメモリ最適化が必要
