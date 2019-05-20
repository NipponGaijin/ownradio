//
//  Downloader.swift
//  OwnRadio
//
//  Created by Roman Litoshko on 12/5/16.
//  Copyright © 2016 Roll'n'Code. All rights reserved.
//
//	Download track in cache

import Foundation
import UIKit
import Alamofire

class Downloader: NSObject {
	
	static let sharedInstance = Downloader()
	//	var taskQueue: OperationQueue?
	let baseURL = URL(string: "http://api.ownradio.ru/v5/tracks/")
    let rdevApiUrl = URL(string: "http://rdev.ownradio.ru/api/executejs")
	let applicationSupportPath = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
	let tracksPath = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.appendingPathComponent("Tracks/")
	let tracksUrlString =  FileManager.applicationSupportDir().appending("/Tracks/")
	
//	let limitMemory =  UInt64(DiskStatus.freeDiskSpaceInBytes / 3)
	var maxMemory = UInt64(1000000000)
	var memoryBuffer = UInt()
	
	var requestCount = 0
	var deleteCount = 0
	var maxRequest = 9
	var maxTryes = 0
	var completionHandler:(()->Void)? = nil
	var notLoadTryes = 0

	func runLoad(isSelf: Bool, complition: @escaping(() -> Void)){
		if requestCount == 0{
			self.load(isSelfFlag: isSelf) {
				self.createPostNotificationSysInfo(message: "Loaded")
				return
			}
		}else if notLoadTryes == 5{
			self.load(isSelfFlag: isSelf) {
				self.createPostNotificationSysInfo(message: "Loaded")
				self.notLoadTryes = 0
				return
			}
		}else{
			self.createPostNotificationSysInfo(message: "Not load, req. count = \(requestCount.description)")
			notLoadTryes = notLoadTryes + 1
			return
		}
	}
	
	func load(isSelfFlag: Bool, complition: @escaping (() -> Void)) {
		print("call load")
		
		
		let memoryAvailable = UInt64(DiskStatus.folderSize(folderPath: tracksUrlString)) + UInt64(DiskStatus.freeDiskSpaceInBytes)
		let percentage = Double((UserDefaults.standard.object(forKey: "maxMemorySize") as? Double)! / 100)
		maxMemory = UInt64(Double(memoryAvailable) * percentage)
		
//		if limitMemory < 1000000000 * ((UserDefaults.standard.object(forKey: "maxMemorySize") as? UInt64)! / 10) {
//			maxMemory = limitMemory
//		} else {
//			let memoryAvailable = UInt64(DiskStatus.folderSize(folderPath: tracksUrlString)) + UInt64(DiskStatus.freeDiskSpaceInBytes)
//			let percentage = Double((UserDefaults.standard.object(forKey: "maxMemorySize") as? Double)! / 100)
//			maxMemory = UInt64(Double(memoryAvailable) * percentage)
//		}
//		+ DiskStatus.folderSize(folderPath: tracksUrlString)))
//		* (DiskStatus.freeDiskSpaceInBytes)
		
		//если треки занимают больше места, чем максимально допустимо -
		//удаляем "лишние" треки - в первую очередь прослушанные, затем, если необходимо - самые старые из загруженных
		while (!isSelfFlag && DiskStatus.folderSize(folderPath: tracksUrlString) > maxMemory) {
			// получаем трек проиграный большее кол-во раз
			let song: [SongObject] = CoreDataManager.instance.getOldTrack(onlyListen: false) as! [SongObject]
			// получаем путь файла
			guard song != nil && song[0].trackID != nil else {
				self.createPostNotificationSysInfo(message: "Не найден трек для удаления")
				return
			}
			self.createPostNotificationSysInfo(message: "Память заполнена. Удаляем трек \(self.deleteCount)")
			
			let songObjectEncoded = UserDefaults.standard.data(forKey: "playingSongObject")
			let currentSongObject = try! PropertyListDecoder().decode(SongObject.self, from: songObjectEncoded!)
			if (song[0].trackID.isEqual(currentSongObject.trackID)) != true{
				deleteOldTrack(song: song[0])
			}
			else{
				if song.count > 1{
					deleteOldTrack(song: song[1])
				}
			}
			
		}
		
		//проверка подключения к интернету
		guard currentReachabilityStatus != NSObject.ReachabilityStatus.notReachable else {
			self.requestCount = 0
			return
		}
		
		//делаем 10 попыток скачивания треков, если место свободное место закончилось, но есть прослушанные треки - удаляем их и загружаем новые, иначе перестаем пытаться скачать
		if DiskStatus.folderSize(folderPath: tracksUrlString) < maxMemory  {
			if UserDefaults.standard.bool(forKey: "trafficOptimize"){
				if CoreDataManager.instance.chekCountOfEntitiesFor(entityName: "TrackEntity") <= 10{
					maxTryes = 1
				}else if CoreDataManager.instance.chekCountOfEntitiesFor(entityName: "TrackEntity") <= 50{
					maxTryes = 0
				}
				else{
					return
				}
			}else{
				maxTryes = 9
			}
			self.maxRequest = maxTryes
			self.deleteCount = 0
			//получаем trackId следующего трека и информацию о нем
			self.completionHandler = complition
			
			if requestCount <= maxTryes{
				RdevApiService().GetTrackInfo(requestCount: self.requestCount) {dict in
					
					guard dict["NotAuthorized"] == nil else{
						self.createPostNotificationSysInfo(message: "GettrackNotAuthorized")
						self.load(isSelfFlag: true){
							
						}
						self.requestCount += 1
						return
					}
					guard dict["ServerError"] == nil else{
						self.createPostNotificationSysInfo(message: "GettrackServerError")
						self.load(isSelfFlag: true){
						}
						self.requestCount += 1
						return
					}
					
					guard dict["recid"] != nil else {
						return
					}
					print(dict["recid"])
					let trackURL = self.baseURL?.appendingPathComponent(dict["recid"] as! String).appendingPathComponent((UIDevice.current.identifierForVendor?.uuidString.lowercased())!)
					if let audioUrl = trackURL {
						//задаем директорию для сохранения трека
						let destinationUrl = self.tracksPath.appendingPathComponent(dict["recid"] as! String)
						//если этот трек не еще не загружен - загружаем трек
						//						let mp3Path = destinationUrl.appendingPathExtension("mp3")
						guard FileManager.default.fileExists(atPath: destinationUrl.path ) == false else {
							self.createPostNotificationSysInfo(message: "Трек уже загружен - пропустим")
							return
						}
						//добавляем трек в очередь загрузки
						//self.createDownloadTask(destinationUrl: destinationUrl, dict: dict)
						self.downloadFile(destinationUrl: destinationUrl, dict: dict)
						
						//						}
					}
				}
			}else{
				self.createPostNotificationSysInfo(message: "\(maxTryes + 1) попыток исчерпано")
				self.requestCount = -1
				return
			}
			
			
		} else {
			// если память заполнена удаляем трек
			if self.deleteCount < maxTryes {
				if self.completionHandler != nil {
					self.completionHandler!()
				}
				self.deleteCount += 1
				
				
				// получаем трек проиграный большее кол-во раз
				let song: [SongObject] = CoreDataManager.instance.getOldTrack(onlyListen: true) as! [SongObject]
				// получаем путь файла
				guard song != nil && song[0].trackID != nil else {
					self.createPostNotificationSysInfo(message: "Память заполнена, нет прослуш треков")
					self.requestCount = 0
					return
				}
				self.createPostNotificationSysInfo(message: "Память заполнена. Удаляем трек \(self.deleteCount)")
				
				let songObjectEncoded = UserDefaults.standard.data(forKey: "playingSongObject")
				let currentSongObject = try! PropertyListDecoder().decode(SongObject.self, from: songObjectEncoded!)
				
				if	(song[0].trackID.isEqual(currentSongObject.trackID)) != true{
					deleteOldTrack(song: song[0])
				}else{
					if song.count > 1{
						deleteOldTrack(song: song[1])
					}
				}
				
				self.load (isSelfFlag: true){
					
				}
				
			}else {
				self.deleteCount = 0
			}
			
		}
	}
	func downloadFile(destinationUrl:URL, dict:[String:Any]){
		print("call createDownloadTask")
		
		let json: Parameters = ["fields":["recid":dict["recid"] as! String], "method":"gettrack", "resulttype":"filestream"]
		let token = UserDefaults.standard.string(forKey: "authToken") as! String
		let headers: HTTPHeaders = [
			"Content-Type":"application/json",
			"Authorization":"Bearer \(token)"
		]
		let mp3Path = destinationUrl.appendingPathExtension("mp3")
		let destination: DownloadRequest.DownloadFileDestination = {_, _ in
			return (mp3Path, [.removePreviousFile])
		}
		guard FileManager.default.fileExists(atPath: mp3Path.path ) == false else {
			self.createPostNotificationSysInfo(message: "MP3 file exist")
			load(isSelfFlag: true) {
				return
			}
			return
		}
		
		do{
			download(rdevApiUrl!, method: .post, parameters: json, encoding: JSONEncoding.default, headers: headers, to: destination).response { (response) in
				if let statusCode = response.response?.statusCode{
					if statusCode == 200{
						let filedata = NSData(contentsOf: mp3Path)
						if let contentLength = Int(response.response?.allHeaderFields["Content-Length"] as! String) {
							if let length = filedata?.length{
								if length != contentLength || length == 0 {
									if FileManager.default.fileExists(atPath: mp3Path.path) {
										do{
											// удаляем обьект по пути
											try FileManager.default.removeItem(atPath: mp3Path.path)
											self.createPostNotificationSysInfo(message: "Файл с длиной = \(filedata!.length), ContentLength = \(contentLength) удален")
										}
										catch {
											print("Ошибка при удалении недокачанного трека")
										}
									}
									return
								}
							}
						}
						//сохраняем информацию о файле в базу данных
						
						
						let trackEntity = TrackEntity()
						
						trackEntity.path = String(describing: mp3Path.lastPathComponent)
						trackEntity.countPlay = 0
						trackEntity.artistName = dict["artist"] as? String
						trackEntity.trackName = dict["recname"] as? String
						trackEntity.trackLength = dict["length"] as! Double
						trackEntity.recId = dict["recid"] as! String?
						trackEntity.playingDate = NSDate.init(timeIntervalSinceNow: -315360000.0042889)
						
						CoreDataManager.instance.saveContext()
						
						self.createPostNotificationSysInfo(message: "Трек (\(self.requestCount+1)) загружен \(trackEntity.recId ?? "")")
						
						if self.requestCount < self.maxRequest {
							if self.completionHandler != nil {
								self.completionHandler!()
							}
							self.requestCount += 1
							self.load(isSelfFlag: true, complition: self.completionHandler!)
							
						} else {
							if self.completionHandler != nil {
								self.completionHandler!()
							}
							self.requestCount = 0
							self.maxRequest = self.maxTryes
						}
						
						//				complition()
						
						print("File moved to documents folder")
					}
					else if statusCode == 401{
						NotificationCenter.default.post(name: NSNotification.Name(rawValue: "updateSysInfo"), object: nil, userInfo: ["message":"Create downloadTask not auth"])
						RdevApiService().GetAuthToken(){_ in
							//self.createDownloadTask(destinationUrl: destinationUrl, dict: dict)
						}
						self.createDownloadTask(destinationUrl: destinationUrl, dict: dict)
					}else if statusCode == 500{
						NotificationCenter.default.post(name: NSNotification.Name(rawValue: "updateSysInfo"), object: nil, userInfo: ["message":"Create downloadtask ServerError"])
						if self.requestCount < self.maxRequest {
							if self.completionHandler != nil {
								self.completionHandler!()
							}
							//self.requestCount += 1
							if UserDefaults.standard.bool(forKey: "trafficOptimize"){
								self.requestCount += 1
							}
							self.load(isSelfFlag: true, complition: self.completionHandler!)
							
						} else {
							if self.completionHandler != nil {
								self.completionHandler!()
							}
							self.requestCount = 0
							self.maxRequest = self.maxTryes
						}
					}
					else{
						NotificationCenter.default.post(name: NSNotification.Name(rawValue: "updateSysInfo"), object: nil, userInfo: ["message":"Create downloadtask error: \(statusCode.description)"])
						if self.requestCount < self.maxRequest {
							if self.completionHandler != nil {
								self.completionHandler!()
							}
							self.requestCount += 1
							self.load(isSelfFlag: true, complition: self.completionHandler!)
							
						} else {
							if self.completionHandler != nil {
								self.completionHandler!()
							}
							self.requestCount = 0
							self.maxRequest = self.maxTryes
						}
					}
				}
			}
		}catch{
			self.requestCount = 0
		}
	}
	
	func createDownloadTask(destinationUrl:URL, dict:[String:Any]){
		print("call createDownloadTask")
        
        let json = ["fields":["recid":dict["recid"] as! String], "method":"gettrack", "resulttype":"filestream"] as [String : Any]
        let jsonBody = try? JSONSerialization.data(withJSONObject: json)
        let token = UserDefaults.standard.string(forKey: "authToken")
		
        var request = URLRequest(url: rdevApiUrl!)
        request.httpMethod = "POST"
		request.setValue("application/json", forHTTPHeaderField: "Content-Type")
		request.setValue("Bearer \(token!)", forHTTPHeaderField: "Authorization")
        request.httpBody = jsonBody
        
        let task =  URLSession.shared.downloadTask(with: request,completionHandler: { (location, response, error) -> Void in
			guard error == nil else {
				self.createPostNotificationSysInfo(message: error.debugDescription)
				return
			}
			guard let newLocation = location, error == nil else {return }
			
			if let httpResponse = response as? HTTPURLResponse {
				if httpResponse.statusCode == 200 {
					do {
						let file = NSData(contentsOf: newLocation)
						let mp3Path = destinationUrl.appendingPathExtension("mp3")
						guard FileManager.default.fileExists(atPath: mp3Path.path ) == false else {
							self.createPostNotificationSysInfo(message: "MP3 file exist")
							self.load(isSelfFlag: true) {
								return
							}
							return
						}
						
						//сохраняем трек
						//задаем конечных путь хранения файла (добавляем расширение)
						let endPath = destinationUrl.appendingPathExtension("mp3")
						try file?.write(to: endPath, options:.noFileProtection)
						
						//Проверяем, полностью ли скачан трек
						if let contentLength = Int(httpResponse.allHeaderFields["Content-Length"] as! String) {
							if file!.length != contentLength || file!.length == 0 {
								if FileManager.default.fileExists(atPath: mp3Path.path) {
									do{
										// удаляем обьект по пути
										try FileManager.default.removeItem(atPath: mp3Path.path)
										self.createPostNotificationSysInfo(message: "Файл с длиной = \(file!.length), ContentLength = \(contentLength) удален")
									}
									catch {
										print("Ошибка при удалении недокачанного трека")
									}
								}
								return
							}
						}
						//сохраняем информацию о файле в базу данных
						
						guard FileManager.default.fileExists(atPath: mp3Path.absoluteString ) == false else {
							self.createPostNotificationSysInfo(message: "MP3 file exist")
							self.load(isSelfFlag: true) {
								return
							}
							return
						}
						
						let trackEntity = TrackEntity()
						
						trackEntity.path = String(describing: endPath.lastPathComponent)
						trackEntity.countPlay = 0
						trackEntity.artistName = dict["artist"] as? String
						trackEntity.trackName = dict["recname"] as? String
						trackEntity.trackLength = dict["length"] as! Double
						trackEntity.recId = dict["recid"] as! String?
						trackEntity.playingDate = NSDate.init(timeIntervalSinceNow: -315360000.0042889)
						
						CoreDataManager.instance.saveContext()
						
						self.createPostNotificationSysInfo(message: "Трек (\(self.requestCount+1)) загружен \(trackEntity.recId ?? "")")
						if self.requestCount < self.maxRequest {
							if self.completionHandler != nil {
								self.completionHandler!()
							}
							self.requestCount += 1
							self.load(isSelfFlag: true, complition: self.completionHandler!)
							
						} else {
							if self.completionHandler != nil {
								self.completionHandler!()
							}
							self.requestCount = 0
							self.maxRequest = self.maxTryes
						}
						
						//				complition()
						
						print("File moved to documents folder")

					} catch let error as NSError {
						print(error.localizedDescription)
					}
                }else if httpResponse.statusCode == 401{
                    NotificationCenter.default.post(name: NSNotification.Name(rawValue: "updateSysInfo"), object: nil, userInfo: ["message":"Create downloadTask not auth"])
                    RdevApiService().GetAuthToken(){_ in
                        //self.createDownloadTask(destinationUrl: destinationUrl, dict: dict)
                    }
					self.createDownloadTask(destinationUrl: destinationUrl, dict: dict)
                }
                else if httpResponse.statusCode == 500{
                    NotificationCenter.default.post(name: NSNotification.Name(rawValue: "updateSysInfo"), object: nil, userInfo: ["message":"Create downloadtask ServerError"])
					if self.requestCount < self.maxRequest {
						if self.completionHandler != nil {
							self.completionHandler!()
						}
						//self.requestCount += 1
						if UserDefaults.standard.bool(forKey: "trafficOptimize"){
							self.requestCount += 1
						}
						self.load(isSelfFlag: true, complition: self.completionHandler!)
						
					} else {
						if self.completionHandler != nil {
							self.completionHandler!()
						}
						self.requestCount = 0
						self.maxRequest = self.maxTryes
					}
                }
                else{
                    NotificationCenter.default.post(name: NSNotification.Name(rawValue: "updateSysInfo"), object: nil, userInfo: ["message":"Create downloadtask error: \(httpResponse.statusCode.description)"])
					if self.requestCount < self.maxRequest {
						if self.completionHandler != nil {
							self.completionHandler!()
						}
						self.requestCount += 1
						self.load(isSelfFlag: true, complition: self.completionHandler!)
						
					} else {
						if self.completionHandler != nil {
							self.completionHandler!()
						}
						self.requestCount = 0
						self.maxRequest = self.maxTryes
					}
                }
            }else{
                NotificationCenter.default.post(name: NSNotification.Name(rawValue: "updateSysInfo"), object: nil, userInfo: ["message":"Create downloadtask error: NOT http"])
            }
		})
        task.resume()
	}

	func createPostNotificationSysInfo (message:String) {
		NotificationCenter.default.post(name: NSNotification.Name(rawValue: "updateSysInfo"), object: nil, userInfo: ["message":message])
	}
	
	// удаление трека если память заполнена
	func deleteOldTrack (song: SongObject?) {
		print("call deleteOldTrack")
		
		let path = self.tracksUrlString.appending((song?.path)!)
		self.createPostNotificationSysInfo(message: "Удаляем \(song!.trackID.description)")
		print("Удаляем \(song!.trackID.description)")
		
		if FileManager.default.fileExists(atPath: path) {
			do{
				// удаляем обьект по пути
				try FileManager.default.removeItem(atPath: path)
				self.createPostNotificationSysInfo(message: "Файл успешно удален")
				print("Файл успешно удален")
			}
			catch {
				self.createPostNotificationSysInfo(message: "Ошибка удаления трека: \(error)")
				print("Ошибка удаления трека: \(error)")
			}
		} else {
			self.createPostNotificationSysInfo(message: "Трек уже удалён с устройства")
			print("Трек уже удалён с устройства")
		}
			// удаляем трек с базы
			//			CoreDataManager.instance.managedObjectContext.performAndWait {
			CoreDataManager.instance.deleteTrackFor(trackID: (song?.trackID)!)
			CoreDataManager.instance.saveContext()
			//			}
			
//		}
	}
	
	func fillCache () {
//		let limitMemory =  UInt64(DiskStatus.freeDiskSpaceInBytes / 2)
//		let maxMemory = 1000000000 * (UserDefaults.standard.object(forKey: "maxMemorySize") as? UInt64)!
		let memoryAvailable = UInt64(DiskStatus.folderSize(folderPath: tracksUrlString)) + UInt64(DiskStatus.freeDiskSpaceInBytes)
		let percentage = Double((UserDefaults.standard.object(forKey: "maxMemorySize") as? Double)! / 100)
		maxMemory = UInt64(Double(memoryAvailable) * percentage)
		let folderSize = DiskStatus.folderSize(folderPath: tracksUrlString)
		if folderSize < maxMemory  {
			self.runLoad (isSelf: true){
				self.fillCache()
			}
		}
	}
	
}
