package ru.netvoxlab.ownradio.rdevapi;

import android.content.Context;
import android.os.AsyncTask;

import java.util.Map;

import retrofit2.Response;
import ru.netvoxlab.ownradio.Utilites;
import ru.netvoxlab.ownradio.rdevApiObjects.RegisterUserBody;

public class RdevRegisterDevice extends AsyncTask<String, Void, Boolean> {
    Context mContext;

    public RdevRegisterDevice(Context context){
        this.mContext = context;
    }


    @Override
    protected Boolean doInBackground(String... strings) {
        try {
            RegisterUserBody body = new RegisterUserBody(strings[0], strings[1]);
            Response<Map<String, Map<String, String>[]>> response = RdevServiceGenerator.createService(RdevAPIService.class).rdevRegisterNewDevice(strings[2], body).execute();
            if (response.isSuccessful() && response.code() == 200){
                return true;
            } else {
                return false;
            }
        } catch (Exception ex) {
            ex.printStackTrace();
            new Utilites().SendInformationTxt(mContext, "Device is not register -  " + ex.getLocalizedMessage());
            return false;
        }
    }

    protected void onPostExecute(Boolean result) {
        super.onPostExecute(result);
    }
}
