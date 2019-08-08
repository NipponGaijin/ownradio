package ru.netvoxlab.ownradio;

import android.content.Context;
import android.net.ConnectivityManager;
import android.net.NetworkInfo;



/**
 * Created by a.polunina on 31.10.2016.
 */

public class CheckConnection {
	
	public boolean CheckInetConnection(Context mCcontext) {
		ConnectivityManager connectivityManager = (ConnectivityManager) mCcontext.getSystemService(mCcontext.CONNECTIVITY_SERVICE);
		NetworkInfo inetInfo = connectivityManager.getActiveNetworkInfo();
		//Если никакого интернет подключения нет - возвращаем false
		if(inetInfo == null || !inetInfo.isConnected()){
			new Utilites().SendInformationTxt(mCcontext, "Internet is disconnected");
			return false;
		}
		return true;
	}
}
