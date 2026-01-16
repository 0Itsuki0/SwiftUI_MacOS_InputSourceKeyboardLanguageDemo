
import Carbon
import Combine
import SwiftUI

@Observable
class SystemInputSourceManager {
    private(set) var inputSources: [TISInputSource] = []
    private(set) var selectedSource: TISInputSource? = nil

    
    private var timerCancellable: AnyCancellable?
    private let timer = Timer.publish(every: 0.2, on: .main, in: .common)

    init() {
        self.refreshInputSources()
        self.timerCancellable = self.timer.autoconnect().sink(receiveValue: {
            [weak self] _ in
            self?.refreshInputSources()
        })
    }

    deinit {
        self.timerCancellable?.cancel()
    }
    
    
    func selectSource(_ source: TISInputSource) throws {
        let result: OSStatus = TISSelectInputSource(source)
        guard result == noErr else {
            throw NSError(domain: "SelectLanguageSourceFailed", code: 500)
        }
    }

    private func getEnabledKeyboardSources() {
        guard
            let inputSources = TISCreateInputSourceList(nil, false)?
                .takeRetainedValue() as? [TISInputSource]
        else {
            return
        }
        let keyboardInputs = inputSources.filter({
            $0.category == kTISCategoryKeyboardInputSource as String
        })
        self.inputSources = keyboardInputs
    }


    
    private func getCurrentKeyboardSource() {
        guard
            let source = TISCopyCurrentKeyboardInputSource()?
                .takeRetainedValue()
        else {
            return
        }
        self.selectedSource = source

    }

    private func refreshInputSources() {
        self.getEnabledKeyboardSources()
        self.getCurrentKeyboardSource()
    }
    
    // for debugging
    private func printSource(_ source: TISInputSource) {
        print("id: \(source.id, default: "(Unknown)")")
        print("Category: \(source.category, default: "(Unknown)")")
        print("Type: \(source.type, default: "(Unknown)")")
        print("localizedName: \(source.localizedName, default: "(Unknown)")")
        print("isSelectCapable: \(source.isSelectCapable)")
        print("isSelected: \(source.isSelected)")

        print("isEnableCapable: \(source.isEnableCapable)")
        print("isEnabled: \(source.isEnabled)")

        print("sourceLanguages: \(source.sourceLanguages)")
        print("iconImageURL: \(source.iconImageURL, default: "(Unknown)")")
    }

}

extension TISInputSource {
    func getProperty(_ key: CFString) -> AnyObject? {
        guard let pointer = TISGetInputSourceProperty(self, key) else {
            return nil
        }
        return Unmanaged<AnyObject>.fromOpaque(pointer).takeUnretainedValue()
    }

    var id: String? {
        let string: String? = getProperty(kTISPropertyInputSourceID) as? String
        return string
    }

    var category: String? {
        let string: String? =
            getProperty(kTISPropertyInputSourceCategory) as? String
        return string
    }

    var type: String? {
        let string: String? =
            getProperty(kTISPropertyInputSourceType) as? String
        return string
    }

    var localizedName: String? {
        let string: String? = getProperty(kTISPropertyLocalizedName) as? String
        return string
    }

    var isSelectCapable: Bool {
        let bool: Bool? =
            getProperty(kTISPropertyInputSourceIsSelectCapable) as? Bool
        return bool ?? false
    }

    var isSelected: Bool {
        let bool: Bool? =
            getProperty(kTISPropertyInputSourceIsSelected) as? Bool
        return bool ?? false
    }

    var isEnableCapable: Bool {
        let bool: Bool? =
            getProperty(kTISPropertyInputSourceIsEnableCapable) as? Bool
        return bool ?? false
    }

    var isEnabled: Bool {
        let bool: Bool? = getProperty(kTISPropertyInputSourceIsEnabled) as? Bool
        return bool ?? false
    }

    var sourceLanguages: [String] {
        let array: [String] =
            getProperty(kTISPropertyInputSourceLanguages) as? [String] ?? []
        return array
    }

    var iconImageURL: URL? {
        let string: URL? = getProperty(kTISPropertyIconImageURL) as? URL
        return string
    }
}

struct SystemInputSourceDemo: View {
    @State private var manager = SystemInputSourceManager()
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24, content: {
                Text("My Keyboard Input Source!")
                    .font(.title2)
                    .fontWeight(.bold)
                
                if manager.inputSources.isEmpty {
                    Text("No Input Source Set up yet!")
                }
                
                ForEach(manager.inputSources.filter({$0.isSelectCapable}), id: \.id) { source in
                    self.inputSourceView(source)
                }
            })
            .scrollTargetLayout()
            .padding()
            .padding(.horizontal, 36)

        }
        .frame(width: 640, height: 360)
    }
    
    @ViewBuilder
    private func inputSourceView(_ source: TISInputSource) -> some View {
        // since we are using inputSource.id for ForEach.id
        // The view will not be updated even if source.isSelected changes
        // Therefore, we are comparing it withe the self.manager.selectedSource instead
        let isSelected = source == self.manager.selectedSource
        HStack {
            VStack(alignment: .leading, spacing: 8, content: {
                Text("ID: \(source.id, default: "(unknown)")")
                    .lineLimit(1)
                Text("Name: \(source.localizedName, default: "(unknown)")")
                Text("Primary source language: \(source.sourceLanguages.first, default: "(unknown)")")
            })
            
            Spacer()
            
            if !isSelected {
                Button(action: {
                    try? self.manager.selectSource(source)
                }, label: {
                    Text(source.isSelectCapable ? "Select" : "Not Selectable")
                })
                .buttonStyle(.borderedProminent)
                .disabled(!source.isSelectCapable)
            }

        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.gray.opacity(0.8))
                .stroke(.link, style: .init(lineWidth: source.isSelected ? 2.0 : 0.0))
                .shadow(radius: 4)
                .scaleEffect(source.isSelected ? 1.05 : 1.0)
        )

    }
}
