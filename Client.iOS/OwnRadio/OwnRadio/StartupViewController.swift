//
//  StartupViewController.swift
//  OwnRadio
//
//  Created by Alexandr Serov on 21.03.2019.
//  Copyright © 2019 Netvox Lab. All rights reserved.
//

import UIKit
import Foundation

class StartupViewController: UIViewController {

	let userDefaults = UserDefaults.standard
	
    override func viewDidLoad() {
        super.viewDidLoad()
		
        // Do any additional setup after loading the view.
		
		let storyboard: UIStoryboard = UIStoryboard(name: "Main", bundle: nil)
		
		if userDefaults.object(forKey: "isAppAlreadyLaunchedOnce") == nil{
			RdevApiService().RegisterDevice { (result) in
				if result{
					self.userDefaults.set(true, forKey: "isAppAlreadyLaunchedOnce")
					print("Приложение запущено впервые")
					sleep(1)
					DispatchQueue.main.async {
						let viewController = storyboard.instantiateViewController(withIdentifier: "FirstLaunchSlider")
						self.navigationController?.pushViewController(viewController, animated: false)
					}
				}
				else{
					let registerErrorAlert = UIAlertController(title: "Ошибка регистрации", message: "Устройство не зарегистрировано, закрыть приложение?", preferredStyle: UIAlertControllerStyle.alert)
					registerErrorAlert.addAction(UIAlertAction(title: "Да", style: .default, handler: { (action: UIAlertAction) in
						exit(0)
					}))
					self.present(registerErrorAlert, animated: true, completion: nil)
				}
			}
		}
		else{
			sleep(1)
			let viewController = storyboard.instantiateViewController(withIdentifier: "RadioViewController")
			self.navigationController?.pushViewController(viewController, animated: false)
		}
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
