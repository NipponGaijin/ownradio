package ru.netvoxlab.ownradio.rdevApiObjects;

public class NexttrackFields {
    String chapter;
    private String mediatype = "track";
    String deviceid;


    public  NexttrackFields(String chapter, String deviceId){
        this.chapter = chapter;
        this.deviceid = deviceId;
    }

    public String getChapter(){
        return chapter;
    }

    public String getDeviceId(){
        return deviceid;
    }

    public String getMediatype(){
        return mediatype;
    }

    public void setChapter(String chapter) {
        this.chapter = chapter;
    }

    public void setDeviceId(String deviceId) {
        this.deviceid = deviceId;
    }
}
