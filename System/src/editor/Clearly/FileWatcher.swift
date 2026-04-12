import Foundation

final class FileWatcher: ObservableObject {
    private let queue = DispatchQueue(label: "com.kindasmd.filewatcher", qos: .utility)
    private var source: DispatchSourceFileSystemObject?
    private var fileDescriptor: Int32 = -1
    private var debounceWork: DispatchWorkItem?
    private var monitoredURL: URL?
    private var currentText: String?
    private var lastKnownDiskText: String?
    var onChange: ((String) -> Void)?

    func watch(_ url: URL?, currentText: String? = nil) {
        queue.sync {
            self._stopMonitoring()
            self.monitoredURL = url
            self.currentText = currentText
            self.lastKnownDiskText = currentText
            guard let url else { return }
            self._startMonitoring(url)
        }
    }

    func updateCurrentText(_ text: String) {
        queue.async { [weak self] in
            self?.currentText = text
        }
    }

    func updateLastKnownDiskText(_ text: String) {
        queue.async { [weak self] in
            self?.lastKnownDiskText = text
        }
    }

    deinit {
        _stopMonitoring()
    }

    // MARK: - Private (must be called on self.queue or from deinit)

    private func _startMonitoring(_ url: URL) {
        let fd = open(url.path, O_EVTONLY)
        guard fd != -1 else { return }
        fileDescriptor = fd

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .delete, .rename, .link, .extend, .attrib],
            queue: queue
        )

        source.setEventHandler { [weak self] in
            guard let self else { return }
            let flags = source.data
            if flags.contains(.delete) || flags.contains(.rename) {
                self._stopMonitoring()
                self.queue.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                    guard let self, let url = self.monitoredURL else { return }
                    self._startMonitoring(url)
                    self._readAndNotify()
                }
                return
            }
            self._debouncedReadAndNotify()
        }

        source.setCancelHandler { [fd] in
            close(fd)
        }

        source.resume()
        self.source = source
    }

    private func _stopMonitoring() {
        debounceWork?.cancel()
        debounceWork = nil
        source?.cancel()
        source = nil
        fileDescriptor = -1
    }

    private func _debouncedReadAndNotify() {
        debounceWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?._readAndNotify()
        }
        debounceWork = work
        queue.asyncAfter(deadline: .now() + 0.3, execute: work)
    }

    private func _readAndNotify() {
        guard let url = monitoredURL else { return }
        guard let data = try? Data(contentsOf: url),
              let newText = String(data: data, encoding: .utf8) else { return }

        let lastKnown = self.lastKnownDiskText
        let current = self.currentText

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard newText != lastKnown else { return }

            let hasUnsavedChanges = current != lastKnown

            self.queue.async { [weak self] in
                self?.lastKnownDiskText = newText
            }

            guard !hasUnsavedChanges else {
                DiagnosticLog.log("External file change ignored: unsaved local edits")
                return
            }

            self.queue.async { [weak self] in
                self?.currentText = newText
            }
            self.onChange?(newText)
        }
    }
}
