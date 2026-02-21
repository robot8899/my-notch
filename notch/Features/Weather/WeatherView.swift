import SwiftUI

struct WeatherView: View {
    var service: WeatherService
    var onBack: (() -> Void)? = nil
    @State private var searchQuery = ""
    @State private var showSearchResults = false
    @FocusState private var isSearchFocused: Bool

    private func clearSearch() {
        searchQuery = ""
        showSearchResults = false
        service.searchResults = []
    }

    var body: some View {
        VStack(spacing: 8) {
            if showSearchResults && !service.searchResults.isEmpty {
                // Search results
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 2) {
                        ForEach(service.searchResults) { result in
                            Button {
                                service.addLocation(result)
                                clearSearch()
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "mappin.circle.fill")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.white.opacity(0.5))
                                    Text(result.displayName)
                                        .font(.system(size: 12))
                                        .foregroundStyle(.white.opacity(0.8))
                                        .lineLimit(1)
                                    Spacer()
                                    Image(systemName: "plus.circle")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.white.opacity(0.4))
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(RoundedRectangle(cornerRadius: 6).fill(.white.opacity(0.05)))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            } else {
                // Weather list
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 4) {
                        ForEach(service.locations) { location in
                            WeatherRowView(
                                location: location,
                                isSelected: service.selectedLocationID == location.id
                                    || (service.selectedLocationID == nil && location.isCurrentLocation)
                            ) {
                                service.selectLocation(location)
                            } onDelete: {
                                service.removeLocation(location)
                            }
                        }
                    }
                }
            }

            // Bottom bar: back button + search field
            HStack(spacing: 8) {
                if let onBack {
                    Button(action: onBack) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 10, weight: .semibold))
                            Text("返回")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(.white.opacity(0.55))
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(Capsule().fill(.white.opacity(0.08)))
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: 8) {
                    TextField("", text: $searchQuery)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .foregroundStyle(.white)
                        .focused($isSearchFocused)
                        .overlay(alignment: .leading) {
                            if searchQuery.isEmpty {
                                Text("搜索城市...")
                                    .font(.system(size: 13))
                                    .foregroundStyle(.white.opacity(0.4))
                                    .allowsHitTesting(false)
                            }
                        }
                        .onChange(of: searchQuery) {
                            if searchQuery.trimmingCharacters(in: .whitespaces).isEmpty {
                                clearSearch()
                            } else {
                                showSearchResults = true
                                service.searchCities(query: searchQuery)
                            }
                        }
                        .onSubmit {
                            service.searchCities(query: searchQuery)
                            showSearchResults = true
                        }

                    if !searchQuery.isEmpty {
                        Button {
                            clearSearch()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(.white.opacity(0.4))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 8).fill(.white.opacity(0.1)))
                .onTapGesture {
                    if let panel = NSApp.windows.first(where: { $0 is NotchPanel }) {
                        panel.makeKey()
                    }
                    isSearchFocused = true
                }
            }
        }
    }
}

struct WeatherRowView: View {
    let location: WeatherLocation
    var isSelected: Bool
    var onSelect: () -> Void
    var onDelete: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onSelect) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 14))
                    .foregroundStyle(isSelected ? .green : .white.opacity(0.3))
            }
            .buttonStyle(.plain)

            if location.isCurrentLocation {
                Image(systemName: "location.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.blue.opacity(0.8))
            }

            Text(location.name)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(1)

            Spacer()

            if let code = location.weatherCode {
                Text(WeatherService.weatherDescription(for: code))
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.5))

                Image(systemName: WeatherService.sfSymbol(for: code))
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.7))
                    .symbolRenderingMode(.hierarchical)
            }

            if let temp = location.temperature {
                Text("\(temp)°")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: 32, alignment: .trailing)
            } else {
                Text("--°")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.3))
                    .frame(width: 32, alignment: .trailing)
            }

            if isHovering && !location.isCurrentLocation {
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovering ? .white.opacity(0.08) : .clear)
        )
        .onHover { isHovering = $0 }
    }
}
