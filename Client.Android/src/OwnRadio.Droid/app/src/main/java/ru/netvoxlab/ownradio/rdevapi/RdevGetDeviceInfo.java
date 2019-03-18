package ru.netvoxlab.ownradio.rdevapi;

import android.content.Context;
import android.content.SharedPreferences;
import android.os.AsyncTask;
import android.preference.PreferenceManager;
import android.util.Log;

import java.io.IOException;
import java.util.Map;

import retrofit2.Response;
import ru.netvoxlab.ownradio.rdevApiObjects.DeviceInfoBody;
import ru.netvoxlab.ownradio.rdevApiObjects.DeviceInfoResponse;

public class RdevGetDeviceInfo extends AsyncTask<String, Void, String> {
    Context mContext;
    SharedPreferences sp;

    public RdevGetDeviceInfo(Context context){
        this.mContext = context;
        this.sp = PreferenceManager.getDefaultSharedPreferences(mContext);
    }

    @Override
    protected String doInBackground(String... strings) {
        DeviceInfoBody body = new DeviceInfoBody(strings[0]);
        try {
            String token = sp.getString("authToken", "");
            Response<DeviceInfoResponse> response = RdevServiceGenerator.createService(RdevAPIService.class).getRdevDeviceInfo("Bearer " + token, body).execute();
            if (response.code() == 200){
                Map<String, String> result = response.body().getResult();
                if (result != null){
                    return result.get("userid");
                }
                else {
                    return null;
                }
            } else if (response.code() == 401){
                Log.d("Unauthorized", String.valueOf(response.code()));
                return "Unauthorized";
            }
            else {
                Log.d("??", String.valueOf(response.code()));
                return null;
            }
        } catch (Exception e) {
            Log.d("RdevGetNextTrack", e.getLocalizedMessage());
            return null;
        }
    }

    protected void onPostExecute(String result) {
        super.onPostExecute(result);
        //trackModel = result;
    }
}
