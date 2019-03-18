package ru.netvoxlab.ownradio.rdevapi;

import android.content.ContentValues;
import android.content.Context;
import android.os.AsyncTask;
import android.util.Log;

import com.google.gson.Gson;

import java.net.HttpURLConnection;

import okhttp3.ResponseBody;
import retrofit2.Response;
import ru.netvoxlab.ownradio.APIService;
import ru.netvoxlab.ownradio.HistoryDataAccess;
import ru.netvoxlab.ownradio.ServiceGenerator;
import ru.netvoxlab.ownradio.Utilites;
import ru.netvoxlab.ownradio.models.HistoryModel;
import ru.netvoxlab.ownradio.rdevApiObjects.SendHistoryInfoBody;

public class RdevSaveHistoryInfo extends AsyncTask<String, Void, Boolean> {
    Context mContext;

    public RdevSaveHistoryInfo(Context context){
        this.mContext = context;
    }

    @Override
    protected Boolean doInBackground(String... strings) {
        final HistoryDataAccess historyDataAccess = new HistoryDataAccess(mContext);
//		final ContentValues historyRecs = historyDataAccess.GetHistoryRec();
//
//		if (historyRecs == null)
//			return true;
//
        final ContentValues historyRec = historyDataAccess.GetHistoryRec();

        try {
//				final ContentValues historyRec = historyDataAccess.GetHistoryRec();
            if (historyRec == null) //Если неотправленной статистики нет - выходим
                return true;

            if (historyRec.getAsString("trackid").equals("")) {
                historyDataAccess.DeleteHistoryRec(historyRec.getAsString("id"));
                return true;
            }

//				HistoryModel data = new HistoryModel("2016-11-16T13:15:15",1,1);
            SendHistoryInfoBody body = new SendHistoryInfoBody(historyRec.getAsString("trackid"), strings[1], historyRec.getAsString("id"), historyRec.getAsString("isListen"), historyRec.getAsString("lastListen"), strings[2]);
//            HistoryModel historyData = new HistoryModel();
//            historyData.setRecId(historyRec.getAsString("id"));
//            historyData.setLastListen(historyRec.getAsString("lastListen"));
//            historyData.setIsListen(historyRec.getAsInteger("isListen"));

            String gsonBody = new Gson().toJson(body);
            Log.d("Json", gsonBody);
            //Response<Void> rweesponse = ServiceGenerator.createService(APIService.class).sendHistory(data[0], historyRec.getAsString("trackid"), historyData).execute();
            Response<ResponseBody> response = RdevServiceGenerator.createService(RdevAPIService.class).sendListensHistory(strings[0], body).execute();
            Log.d("resp", response.body().string());

            if (response.isSuccessful()) {
                if (response.code() == 200) {
                    historyDataAccess.DeleteHistoryRec(historyRec.getAsString("id"));
                    new Utilites().SendInformationTxt(mContext, "History by trackId " + historyRec.getAsString("trackid") + " is sending with response code=" + response.code());
                } else {
                    new Utilites().SendInformationTxt(mContext, "Error: History by trackId " + historyRec.getAsString("trackid")+ " not send with response code=" + response.code());
                }
            }
            else {
                if(response.code() == HttpURLConnection.HTTP_NOT_FOUND || response.code() == HttpURLConnection.HTTP_CONFLICT){
                    historyDataAccess.DeleteHistoryRec(historyRec.getAsString("id"));
                    new Utilites().SendInformationTxt(mContext, "Error: History by trackId " + historyRec.getAsString("trackid") + " not send with response code=" + response.code());
                }
            }
        } catch (Exception ex) {
            ex.printStackTrace();
            new Utilites().SendInformationTxt(mContext,"Error: History by trackId " + historyRec.getAsString("trackid")+ " not send with exception="  + ex.getLocalizedMessage());
            return false;
        }
        return true;
    }

    protected void onPostExecute(Boolean result) {
        super.onPostExecute(result);
    }
}
