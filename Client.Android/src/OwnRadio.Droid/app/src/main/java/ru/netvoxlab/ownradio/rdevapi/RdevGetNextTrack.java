package ru.netvoxlab.ownradio.rdevapi;

import android.content.Context;
import android.os.AsyncTask;
import android.util.ArrayMap;
import android.util.Log;

import com.google.gson.Gson;
import com.google.gson.JsonObject;

import org.json.JSONObject;

import java.util.List;
import java.util.Map;

import retrofit2.Response;
import ru.netvoxlab.ownradio.Utilites;
import ru.netvoxlab.ownradio.rdevApiObjects.NextTrackBody;
import ru.netvoxlab.ownradio.rdevApiObjects.NexttrackFields;

public class RdevGetNextTrack extends AsyncTask<String, Void, Map<String, Map<String, String>[]>> {
    Context mContext;

    public RdevGetNextTrack(Context context){
        this.mContext = context;
    }


    @Override
    protected Map<String, Map<String, String>[]> doInBackground(String... strings) {
        try{
            NexttrackFields bodyFields = new NexttrackFields("", strings[1]);
            NextTrackBody body = new NextTrackBody(bodyFields);
            String bodyJson = new Gson().toJson(body);
            Log.d("Bearer", strings[0]);
            Log.d("Body", bodyJson);
            Response<Map<String, Map<String, String>[]>> response = RdevServiceGenerator.createService(RdevAPIService.class).getRdevNextTrack(strings[0], body).execute();
            if (response.code() == 200) {
                new Utilites().SendInformationTxt(mContext, "RdevGetNextTrack: Information about next track is received.");
                Log.d("GetTrackSuccess", "SUCCESS");
                return response.body();
            }else {
                new Utilites().SendInformationTxt(mContext, "RdevGetNextTrack: Error with response code: " + response.code());
                Log.d("GetTrackFail", String.valueOf(response.code()));
                Log.d("GetTrackFail", response.message());
                return null;
            }
        }catch (Exception ex){
            Log.d("RdevGetNextTrack", ex.getLocalizedMessage());
            return null;
        }
    }

    protected void onPostExecute(Map<String, Map<String, String>[]> result) {
        super.onPostExecute(result);
        //trackModel = result;
    }
}
