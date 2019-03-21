package ru.netvoxlab.ownradio.rdevApiObjects;

public class NextTrackBody {
    NexttrackFields fields;
    private String method = "nexttrack";

    public NextTrackBody(NexttrackFields fields){
        this.fields = fields;
    }

    public NexttrackFields getFields() {
        return fields;
    }

    public String getMethod() {
        return method;
    }

    public void setFields(NexttrackFields fields){
        this.fields = fields;
    }
}
