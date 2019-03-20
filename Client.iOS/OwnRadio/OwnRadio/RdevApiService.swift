//
//  RdevApiService.swift
//  OwnRadio
//
//  Created by Alexandr Serov on 19.03.2019.
//  Copyright © 2019 Netvox Lab. All rights reserved.
//

import Foundation
import UIKit


class RdevApiService {
	
	let loginUrl = URL(string: "http://rdev.ownradio.ru/auth/login")
	let apiUrl = URL(string: "http://rdev.ownradio.ru/api/executejs")
	var countRequest:Int! = 0
	let userDefault = UserDefaults.standard
	static let shared = ApiService()
	
	init() {
	}
	
	//Получение токена аутентификации
	func GetAuthToken(completion: @escaping (String)->()){
		
		let json: [String: String] = ["login": "admin",
									  "password" : "2128506"]
		let jsonData = try? JSONSerialization.data(withJSONObject: json)
		
		var request = URLRequest(url: loginUrl!)
		request.httpMethod = "POST"
		request.setValue("application/json", forHTTPHeaderField: "Content-Type")
		request.httpBody = jsonData
		
		
		let task = URLSession.shared.dataTask(with: request){ data, response, error in
			guard let data = data, error == nil else{
				print("error: \(error!.localizedDescription)")
				NotificationCenter.default.post(name: NSNotification.Name(rawValue: "updateSysInfo"), object: nil, userInfo: ["message":"AUTH request fail: \(error.debugDescription)"])
				return
			}
			if let httpResponse = response as? HTTPURLResponse{
				print(httpResponse.statusCode)
				if httpResponse.statusCode == 200{
					let responseJson = try? JSONSerialization.jsonObject(with: data, options: [])
					if let responseJson = responseJson as? [String: String]{
						if responseJson["token"] != nil{
							self.userDefault.set(responseJson["token"], forKey: "authToken")
							return completion(responseJson["token"]!)
						}
					}
					else{
						NotificationCenter.default.post(name: NSNotification.Name(rawValue: "updateSysInfo"), object: nil, userInfo: ["message":"AUTH fail: notHttpResponse"])
						return completion("Not HTTP")
					}
				}
				else{
					NotificationCenter.default.post(name: NSNotification.Name(rawValue: "updateSysInfo"), object: nil, userInfo: ["message":"AUTH fail: \(httpResponse.statusCode.description)"])
					return completion("Not success")
				}
			}
			else{
				NotificationCenter.default.post(name: NSNotification.Name(rawValue: "updateSysInfo"), object: nil, userInfo: ["message":"AUTH fail: No response"])
				return completion("No response")
			}
		}
		task.resume()
	}
	
	//Регистрация устройства
	func RegisterDevice(completion: @escaping (Bool)->()) {
		
		let systemVersion = UIDevice.current.systemVersion
		let model = UIDevice.current.model
		var deviceName: String? = model + " " + systemVersion
		let deviceId = UIDevice.current.identifierForVendor?.uuidString.lowercased()
		
		let json: [String: Any] = ["fields": ["recid": deviceId, "recname":deviceName ?? "New IOS device"], "method":"regnewdevice"]
		let jsonData = try? JSONSerialization.data(withJSONObject: json)
		
		var request = URLRequest(url: apiUrl!)
		request.httpMethod = "POST"
		let token = userDefault.string(forKey: "authToken")
		request.setValue("application/json", forHTTPHeaderField: "Content-Type")
		request.setValue("Bearer \(token!)", forHTTPHeaderField: "Authorization")
		request.httpBody = jsonData
		
		let task = URLSession.shared.dataTask(with: request){ data, response, error in
			guard let data = data, error == nil else{
				print("error: \(error!.localizedDescription)")
				NotificationCenter.default.post(name: NSNotification.Name(rawValue: "updateSysInfo"), object: nil, userInfo: ["message":"Register request fail: \(error.debugDescription)"])
				return
			}
			if let httpResponse = response as? HTTPURLResponse{
				print(httpResponse.statusCode)
				if httpResponse.statusCode == 200{
					NotificationCenter.default.post(name: NSNotification.Name(rawValue: "updateSysInfo"), object: nil, userInfo: ["message":"Device registered"])
					self.userDefault.set(deviceId, forKey: "deviceIdentifier")
					return completion(true)
				}
				else if httpResponse.statusCode == 401{
					self.GetAuthToken(completion: { (_) in
						NotificationCenter.default.post(name: NSNotification.Name(rawValue: "updateSysInfo"), object: nil, userInfo: ["message":"Register request unauth: \(httpResponse.statusCode.description)"])
						self.RegisterDevice(completion: {_ in
							
						})
					})
				}
				else{
					NotificationCenter.default.post(name: NSNotification.Name(rawValue: "updateSysInfo"), object: nil, userInfo: ["message":"Register request fail: \(httpResponse.statusCode.description)"])
					return completion(false)
				}
			}else{
				NotificationCenter.default.post(name: NSNotification.Name(rawValue: "updateSysInfo"), object: nil, userInfo: ["message":"NotHTTPresponse"])
				return completion(false)
			}
		}
		task.resume()
	}
	
	//Получение инфы о следующем треке
	func GetTrackInfo(requestCount: Int, complition:  @escaping ([String:Any]) -> Void){
		let token = userDefault.string(forKey: "authToken")
		let deviceid = userDefault.string(forKey: "deviceIdentifier")
//		if deviceid == nil || deviceid == ""{
//
//		}
		
		let json: [String:Any] = ["fields":["chapter":"", "deviceid": deviceid, "mediatype":"track"], "method":"nexttrack"]
		let jsonData = try? JSONSerialization.data(withJSONObject: json)
		
		var request = URLRequest(url: apiUrl!)
		request.httpMethod = "POST"
		request.addValue("application/json", forHTTPHeaderField: "Content-Type")
		request.addValue("Bearer \(token ?? "")", forHTTPHeaderField: "Authorization")
		request.httpBody = jsonData
		let task = URLSession.shared.dataTask(with: request){ data, response, error in
			if error != nil {
				if self.countRequest < 10 {
					Downloader.sharedInstance.load(isSelfFlag: false, complition: {
						
					})
				}
			}
			guard let data = data else {
				return
			}
			if let httpResponse = response as? HTTPURLResponse {
				if httpResponse.statusCode == 200 {
					do {
						let anyJson = try JSONSerialization.jsonObject(with: data, options: [])
						
						if let json = anyJson as? [String:AnyObject] {
							let result = json["result"] as! NSArray
							var resultDict = result[0] as! [String:Any]
							NotificationCenter.default.post(name: NSNotification.Name(rawValue: "updateSysInfo"), object: nil, userInfo: ["message":"(\(requestCount+1))Получ. инфа о загруж. треке (\(resultDict["recid"]))"])
							print("Получена информация о следующем треке \(resultDict["recid"])")
							//resultDict = ["id":resultDict["recid"], "name":resultDict["recname"], "artist":resultDict["artist"], "length":resultDict["length"]]
							if resultDict["artist"] is NSNull{
								resultDict["artist"] = "Artist"
							}
							if resultDict["recname"] is NSNull{
								resultDict["recname"] = "Track"
							}
							complition(resultDict)
						}
						
					} catch (let error) {
						print("Achtung! Eror! \(error)")
					}
				}else if httpResponse.statusCode == 401{
					self.GetAuthToken(){_ in
					}
					self.GetTrackInfo(requestCount: requestCount, complition: { (_) in
					})
					NotificationCenter.default.post(name: NSNotification.Name(rawValue: "updateSysInfo"), object: nil, userInfo: ["message":"GetTrackNotAuthorized"])
				}
				else if httpResponse.statusCode == 500{
					self.RegisterDevice(){result in
						NotificationCenter.default.post(name: NSNotification.Name(rawValue: "updateSysInfo"), object: nil, userInfo: ["message":"GetTrack deviceNotRegistered"])
						if !result{
							NotificationCenter.default.post(name: NSNotification.Name(rawValue: "updateSysInfo"), object: nil, userInfo: ["message":"GetTrack deviceStillNotRegistered"])
							return
						}else{
							self.GetTrackInfo(requestCount: requestCount){getTrackResponse in
								NotificationCenter.default.post(name: NSNotification.Name(rawValue: "updateSysInfo"), object: nil, userInfo: ["message":"GetTrack device was not registered"])
							}
						}
					}
				}
				else{
					
				}
			}else{
				NotificationCenter.default.post(name: NSNotification.Name(rawValue: "updateSysInfo"), object: nil, userInfo: ["message":"GetTrackNotHttp"])
			}
		}
		task.resume()
	}
	
}
