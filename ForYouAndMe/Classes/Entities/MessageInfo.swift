//
//  MessageInfo.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 16/12/24.
//

struct MessageInfo {
    let title: String
    let body: String
}

struct MessageMap {
    static let messages: [String: MessageInfo] = [
        "feed": MessageInfo(title: "COMING SOON #1", body: "There will be a series of slides that explains how the various components of the app works and how it's supposed to be used"),
        "task": MessageInfo(title: "COMING SOON #2", body: "Harmonization of tasks descriptions"),
        "diary": MessageInfo(title: "COMING SOON #3", body: "Options to keep this information private or share beyond the device"),
        "user_data": MessageInfo(title: "COMING SOON #4", body: "Additional chart features and descriptions to follow"),
        "settings": MessageInfo(title: "COMING SOON #5", body: "Set your personalized notifications"),
        "noticed": MessageInfo(title: "About \"I've Noticed\"", body: "You can log a moment, feeling, experience, event, symptom or anything you like, whenever you like by clicking on the + button. You have the option to write a note, record an audio clip, or take a video to describe these moments. If you're not sure what to log, you might consider things that have happened to you throughout the day such as I ate waffles for breakfast, or I had a really stressful afternoon meeting at work. You might also consider logging moments that have just happened and have relevance to your unique condition, such as: 'I just fell when trying to reach for a glass'"),
    ]
}

extension MessageMap {
    static func getMessageContent(byKey key: String) -> MessageInfo? {
        return messages[key]
    }
}
