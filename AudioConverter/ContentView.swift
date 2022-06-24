//
//  ContentView.swift
//  AudioConverter
//
//  Created by John on 2022/6/24.
//

import SwiftUI

struct ContentView: View {
    
    @State var outputPath: URL?
    @State var inputFiles: [URL] = []
    @State var message: String?
    @State var showPopup = false
    @State var loading = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .center) {
                Spacer()
                Image("Icon").resizable().frame(width: 32, height: 32)
                Text("音频转换器").font(.system(size: 28))
                Spacer()
            }
            HStack() {
                Spacer()
                Button(action: {
                    self.showPopup.toggle()
                }, label: {
                    Text("提示")
                })
                .alert(isPresented: self.$showPopup, content: {
                    Alert(title: Text("温馨提示"),
                          message: Text("请注意避免文件名重复，否则会导致输出文件互相覆盖。\n转换过程中如果遇到弹窗询问是否允许访问指定目录，请允许。"),
                          dismissButton: .default(Text("确定"), action: {
                        
                    }))
                    
                })
            }
            
            Text("输入文件：")
            HStack() {
                if inputFiles.count > 0 {
                    List() {
                        ForEach(self.inputFiles, id: \.self) {url in
                            Text("\(url.lastPathComponent)")
                        }
                    }
                    .padding(6)
                } else {
                    Text("拖动音频文件到这里")
                        .font(.system(size: 24))
                        .foregroundColor(Color.gray)
                }
            }
            .frame(width: 380, height: 300)
            .background() {
                ZStack() {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white)
                        .frame(width: 380, height: 300).zIndex(-1)
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.blue, style: StrokeStyle(lineWidth: 3, dash: [10]))
                        .frame(width: 380, height: 300)
                }
                
            }
            .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                self.inputFiles = self.performDropAudio(providers: providers)
                return true
            }
            Text("输出目录：")
            HStack() {
            }
            .frame(width: 380, height: 100)
            .overlay {
                ZStack() {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white)
                        .frame(width: 380, height: 100)
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.blue, style: StrokeStyle(lineWidth: 3, dash: [10]))
                        .frame(width: 380, height: 100)
                    if let outputPath = self.outputPath {
                        Text("\(outputPath.path)")
                            .font(.system(size: 16))
                            .foregroundColor(Color.gray)
                        
                    } else {
                        Text("拖动输出文件夹到这里")
                            .font(.system(size: 20))
                            .foregroundColor(Color.gray)
                    }
                }
                
            }
            .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                self.outputPath = self.performDropOutput(providers: providers)
                return true
            }
            HStack() {
                if let message = self.message {
                    Text("\(message)")
                        .foregroundColor(Color.red)
                }
                Spacer()
                Button(action: {
                    if self.loading {
                        self.loading = false
                        self.message = "转换已中止"
                        return
                    }
                    guard self.inputFiles.count > 0 else {
                        self.message = "请添加输入文件"
                        return
                    }
                    guard self.outputPath != nil else {
                        self.message = "请设置输出文件夹"
                        return
                    }
                    self.convert()
                    
                }) {
                    if self.loading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.6)
                        Text("停止转换")
                    } else {
                        Text("开始转换")
                    }
                }
                .foregroundColor(.white)
                .frame(width: 100, height: 40)
                .buttonStyle(PlainButtonStyle())
                .background(RoundedRectangle(cornerRadius: 8).fill(self.loading ? .red : .blue))
                .padding()
            }
        }
        .padding(30)
        .frame(width: 440)
    }
    
    func performDropAudio(providers: [NSItemProvider]) -> [URL] {
        var fileURLs: [URL] = []
        let group = DispatchGroup()
        for provider in providers {
            guard provider.canLoadObject(ofClass: URL.self) else { continue }
            print("url loaded")
            group.enter()
            let _ = provider.loadObject(ofClass: URL.self) { (url, err) in
                if let url = url {
                    print("url: \(url)")
                    if url.isFileURL && url.pathExtension == "m4a" {
                        fileURLs.append(url)
                    }
                }
                group.leave()
            }
        }
        group.wait()
        print("\(fileURLs)");
        return fileURLs
    }
    
    func performDropOutput(providers: [NSItemProvider]) -> URL? {
        var folderURL: URL?
        let group = DispatchGroup()
        if let provider = providers.first(where: { $0.canLoadObject(ofClass: URL.self) } ) {
            group.enter()
            let _ = provider.loadObject(ofClass: URL.self) { object, error in
                if let url = object {
                    if (try? url.resourceValues(forKeys: [URLResourceKey.isDirectoryKey]))!.isDirectory ?? false {
                        print("url: \(url)")
                        folderURL = url
                    }
                }
                group.leave()
            }
            group.wait()
        }
        return folderURL
    }
    
    func shell(_ launchPath: String, _ arguments: [String]) -> String?
    {
        print("\(launchPath) \(arguments.joined(separator: " "))")
        let task = Process()
        task.launchPath = launchPath
        task.arguments = arguments
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.launch()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: String.Encoding.utf8)
        return output
    }
    
    func convert() {
        self.loading = true
        let totalCount = self.inputFiles.count
        var finishedCount = 0;
        self.message = "转换中 \(finishedCount)/\(totalCount) ..."
        DispatchQueue.global(qos: .background).async {
            let ffmpegPath = Bundle.main.url(forResource: "ffmpeg", withExtension: "")!.path
            self.inputFiles.forEach { url in
                if !self.loading {
                    return
                }
                var outputFile = url.lastPathComponent
                let index = outputFile.index(outputFile.endIndex, offsetBy: -3)
                outputFile = url.lastPathComponent[..<index] + "mp3"
                let outputPath: String = self.outputPath!.appendingPathComponent(outputFile).path
                shell(ffmpegPath, ["-y", "-i", url.path, outputPath])
                if !self.loading {
                    return
                }
                finishedCount += 1
                DispatchQueue.main.async {
                    self.message = "转换中 \(finishedCount)/\(totalCount) ..."
                }
                
            }
            if !self.loading {
                return
            }
            DispatchQueue.main.async {
                self.loading = false
                self.message = "转换完成"
            }
        }
        
    }
}

@available(macOS 13.0, *)
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
