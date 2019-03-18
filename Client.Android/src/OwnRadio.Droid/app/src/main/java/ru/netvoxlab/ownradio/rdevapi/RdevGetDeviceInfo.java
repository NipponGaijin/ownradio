package ru.netvoxlab.ownradio.rdevapi;

import android.content.Context;
import android.os.AsyncTask;
import android.util.Log;

import java.io.IOException;
import java.util.Map;

import retrofit2.Response;
import ru.netvoxlab.ownradio.rdevApiObjects.DeviceInfoBody;
import ru.netvoxlab.ownradio.rdevApiObjects.DeviceInfoResponse;

public class RdevGetDeviceInfo extends AsyncTask<String, Void, String> {
    Context mContext;

    public RdevGetDeviceInfo(Context context){
        this.mContext = context;
    }

    @Override
    protected String doInBackground(String... strings) {
        DeviceInfoBody body = new DeviceInfoBody(strings[1]);
        try {
            Response<DeviceInfoResponse> response = RdevServiceGenerator.createService(RdevAPIService.class).getRdevDeviceInfo(strings[0], body).execute();
            if (response.code() == 200){
                Map<String, String> result = response.body().getResult();
                if (result != null){
                    return result.get("userid");
                }
                else {
                    return null;
                }
            }
            else {
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
