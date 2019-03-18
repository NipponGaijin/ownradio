package ru.netvoxlab.ownradio.rdevapi;

import android.content.Context;
import android.util.ArrayMap;

import com.google.gson.JsonObject;

import java.util.List;
import java.util.Map;
import java.util.UUID;

import ru.netvoxlab.ownradio.CheckConnection;

import ru.netvoxlab.ownradio.Utilites;

public class RdevApiCalls {

    Context mContext;

    public RdevApiCalls(Context context){
        this.mContext = context;
    }

    public Map<String, String> GetAuthToken(){
        CheckConnection checkConnection = new CheckConnection();
        boolean internetConnect = checkConnection.CheckInetConnection(mContext);
        if (!internetConnect)
            return null;
        try {
            Map<String, String> result = new RdevGetAuthToken(mContext).execute().get();
            if (result == null)
                return null;
            return result;
        } catch (Exception ex) {
            new Utilites().SendInformationTxt(mContext, "Error by GetAuthToken " + ex.getLocalizedMessage());
            return null;
        }
    }

    public Map<String, Map<String, String>[]> GetNextTrack(String authToken, String deviceId){
        CheckConnection checkConnection = new CheckConnection();
        boolean internetConnect = checkConnection.CheckInetConnection(mContext);
        if (!internetConnect)
            return null;
        try {
            Map<String, Map<String, String>[]> result = new RdevGetNextTrack(mContext).execute(authToken, deviceId).get();
            if (result == null)
                return null;
            return result;
        } catch (Exception ex) {
            new Utilites().SendInformationTxt(mContext, "Error by GetAuthToken " + ex.getLocalizedMessage());
            return null;
        }
    }

    public void RegisterDevice(String token,String deviceId, String deviceName) {
        CheckConnection checkConnection = new CheckConnection();
        if (!checkConnection.CheckInetConnection(mContext)) {
            return;
        }

        try {
            Boolean result = new RdevRegisterDevice(mContext).execute(deviceId, deviceName, "Bearer " + token).get();
        } catch (Exception ex) {
            new Utilites().SendInformationTxt(mContext, "Error by registerDevice " + ex.getLocalizedMessage());
        }

    }

    public String GetDeviceInfo(String token, String recid){
        CheckConnection checkConnection = new CheckConnection();
        if (!checkConnection.CheckInetConnection(mContext)) {
            return null;
        }

        try {
            String result = new RdevGetDeviceInfo(mContext).execute("Bearer " + token, recid).get();
            if (result != null){
                return result;
            }
            else {return null;}
        } catch (Exception ex) {
            new Utilites().SendInformationTxt(mContext, "Error by registerDevice " + ex.getLocalizedMessage());
            return null;
        }
    }

    public Boolean SendHistoryInfo(String token, String userid, String deviceid){
        CheckConnection checkConnection = new CheckConnection();
        if (!checkConnection.CheckInetConnection(mContext)) {
            return null;
        }

        try {
            Boolean result = new RdevSaveHistoryInfo(mContext).execute("Bearer " + token, deviceid, userid).get();
            if(result){
                return true;
            } else {
                return false;
            }

        } catch (Exception ex) {
            new Utilites().SendInformationTxt(mContext, "Error by registerDevice " + ex.getLocalizedMessage());
            return null;
        }
    }

}
