package ru.netvoxlab.ownradio.rdevapi;

import android.content.Context;
import android.content.SharedPreferences;
import android.preference.PreferenceManager;
import android.util.ArrayMap;

import com.google.gson.JsonObject;

import java.util.List;
import java.util.Map;
import java.util.UUID;

import ru.netvoxlab.ownradio.CheckConnection;

import ru.netvoxlab.ownradio.Utilites;

public class RdevApiCalls {

    Context mContext;
    SharedPreferences sp;
    public RdevApiCalls(Context context){
        this.mContext = context;
        this.sp = PreferenceManager.getDefaultSharedPreferences(context);
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

    public Map<String, Map<String, String>[]> GetNextTrack(String deviceId){
        CheckConnection checkConnection = new CheckConnection();
        boolean internetConnect = checkConnection.CheckInetConnection(mContext);
        if (!internetConnect)
            return null;
        try {
            Map<String, Map<String, String>[]> result = new RdevGetNextTrack(mContext).execute(deviceId).get();
            if (result == null)
                return null;
            else if (result.get("unauth") != null){
                GetAuthToken();
                GetNextTrack(deviceId);
            }
            return result;
        } catch (Exception ex) {
            new Utilites().SendInformationTxt(mContext, "Error by GetAuthToken " + ex.getLocalizedMessage());
            return null;
        }
    }

    public void RegisterDevice(String deviceId, String deviceName) {
        CheckConnection checkConnection = new CheckConnection();
        if (!checkConnection.CheckInetConnection(mContext)) {
            return;
        }

        try {
            Boolean result = new RdevRegisterDevice(mContext).execute(deviceId, deviceName).get();
            if(result == null){
                GetAuthToken();
                RegisterDevice(deviceId, deviceName);
            }
        } catch (Exception ex) {
            new Utilites().SendInformationTxt(mContext, "Error by registerDevice " + ex.getLocalizedMessage());
        }

    }

    public String GetDeviceInfo(String recid){
        String result;
        CheckConnection checkConnection = new CheckConnection();
        if (!checkConnection.CheckInetConnection(mContext)) {
            return null;
        }

        try {

            result = new RdevGetDeviceInfo(mContext).execute(recid).get();
            if (result == null) {
                return null;
            }else if(result == "Unauthorized"){
                GetAuthToken();
                result = GetDeviceInfo(recid);

            }
            return result;
        } catch (Exception ex) {
            new Utilites().SendInformationTxt(mContext, "Error by GetDeviceInfo " + ex.getLocalizedMessage());
            return null;
        }
    }

    public Boolean SendHistoryInfo(String userid, String deviceid){
        CheckConnection checkConnection = new CheckConnection();
        if (!checkConnection.CheckInetConnection(mContext)) {
            return null;
        }

        try {
            Boolean result = new RdevSaveHistoryInfo(mContext).execute(deviceid, userid).get();
            if(result != null && result){
                return true;
            }else if(result == null){
                GetAuthToken();
                SendHistoryInfo(userid, deviceid);
            }
            return false;

        } catch (Exception ex) {
            new Utilites().SendInformationTxt(mContext, "Error by SendHistoryInfo " + ex.getLocalizedMessage());
            return null;
        }
    }

    public void SetIsCorrect(String trackId, Boolean isCorrect){
        CheckConnection checkConnection = new CheckConnection();
        if (!checkConnection.CheckInetConnection(mContext)) {
            return;
        }

        try{
            Boolean result = new RdevSetIsCorrect(mContext).execute(trackId, String.valueOf(isCorrect)).get();
            if(result != null && result){
                return;
            }else if(result == null){
                GetAuthToken();
                SetIsCorrect(trackId, isCorrect);
            }

        }catch (Exception ex) {
            new Utilites().SendInformationTxt(mContext, "Error by SetIsCorrect " + ex.getLocalizedMessage());
                return;
        }
    }


}
