//
//  ContentView.swift
//  ZennVlog
//
//  Created by 保坂篤志 on 2026/01/25.
//

import SwiftUI

@MainActor
struct ContentView: View {
    @AppStorage("hasShownInitialChat") private var hasShownInitialChat = false
    @State private var selectedTab: RootTab = .home
    @State private var homeViewModel: HomeViewModel
    @State private var projectListViewModel: ProjectListViewModel

    private let launchesChatOnFirstOpen: Bool

    init(
        container: DIContainer = .shared,
        launchesChatOnFirstOpen: Bool = true
    ) {
        let homeUseCase = FetchDashboardUseCase(repository: container.projectRepository)
        let projectListUseCase = FetchProjectsUseCase(repository: container.projectRepository)
        _homeViewModel = State(
            wrappedValue: HomeViewModel(fetchDashboardUseCase: homeUseCase)
        )
        _projectListViewModel = State(
            wrappedValue: ProjectListViewModel(fetchProjectsUseCase: projectListUseCase)
        )
        self.launchesChatOnFirstOpen = launchesChatOnFirstOpen
    }

    var body: some View {
        rootView
    }

    private func launchInitialChatIfNeeded() async {
        guard launchesChatOnFirstOpen else { return }
        guard !hasShownInitialChat else { return }

        // Ensure Home tab is active before presenting the initial chat.
        selectedTab = .home
        await Task.yield()
        homeViewModel.startNewProject()
        hasShownInitialChat = true
    }

    @ViewBuilder
    private var rootView: some View {
        #if DEBUG
        if PreviewFeatureDevelopment.launchMode == .preview {
            PreviewFeatureDevelopmentRootView()
        } else {
            mainTabView
        }
        #else
        mainTabView
        #endif
    }

    private var mainTabView: some View {
        TabView(selection: $selectedTab) {
            HomeView(viewModel: homeViewModel)
                .tabItem {
                    Label("ホーム", systemImage: "house.fill")
                }
                .tag(RootTab.home)

            ProjectListView(viewModel: projectListViewModel)
                .tabItem {
                    Label("プロジェクト", systemImage: "list.bullet.rectangle")
                }
                .tag(RootTab.projects)
        }
        .task {
            await launchInitialChatIfNeeded()
        }
    }
}

#Preview {
    ContentView(container: .preview, launchesChatOnFirstOpen: false)
}

private enum RootTab {
    case home
    case projects
}
