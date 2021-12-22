//
//  MessageCenter.swift
//  ApptentiveUnitTests
//
//  Created by Luqmaan Khan on 9/14/21.
//  Copyright © 2021 Apptentive, Inc. All rights reserved.
//

import Foundation
import XCTest

@testable import ApptentiveKit

class MessageCenterViewModelTests: XCTestCase {
    var environment = MockEnvironment()
    var viewModel: MessageCenterViewModel?
    var spySender: SpyInteractionDelegate?

    override func setUpWithError() throws {
        try MockEnvironment.cleanContainerURL()

        let interaction = try InteractionTestHelpers.loadInteraction(named: "MessageCenter")
        guard case let Interaction.InteractionConfiguration.messageCenter(configuration) = interaction.configuration else {
            return XCTFail("Unable to create view model")
        }
        self.spySender = SpyInteractionDelegate()
        self.viewModel = MessageCenterViewModel(configuration: configuration, interaction: interaction, delegate: self.spySender!)
    }

    func testMesssageCenterMetaData() {
        guard let viewModel = self.viewModel else {
            return XCTFail("Unable to load view model.")
        }

        XCTAssertEqual(viewModel.headingTitle, "Message Center")
        XCTAssertEqual(viewModel.branding, "Powered By Apptentive")
        XCTAssertEqual(viewModel.composerTitle, "New Message")
        XCTAssertEqual(viewModel.greetingTitle, "Hello!")
        XCTAssertEqual(viewModel.statusBody, "We will respond to your message soon.")
        XCTAssertEqual(viewModel.automatedMessageBody, "We're sorry to hear that you don't love FooApp! Is there anything we could do to make it better?")
    }

    func testDecodingMessageList() throws {
        guard let directoryURL = Bundle(for: type(of: self)).url(forResource: "Test Interactions", withExtension: nil) else {
            return XCTFail("Unable to find test data")
        }

        let localFileManager = FileManager()

        let resourceKeys = Set<URLResourceKey>([.nameKey])
        let directoryEnumerator = localFileManager.enumerator(at: directoryURL, includingPropertiesForKeys: Array(resourceKeys))!

        for case let fileURL as URL in directoryEnumerator {
            if fileURL.absoluteString.contains("MessageList.json") {
                let data = try Data(contentsOf: fileURL)

                let _ = try JSONDecoder().decode(MessageList.self, from: data)
            }
        }
    }

    func testMessageListPersistence() throws {
        let containerURL = try self.environment.applicationSupportURL().appendingPathComponent("com.apptentive.feedback")
        let messageList = MessageList(
            messages: [
                MessageList.Message(
                    id: "abc123", body: "test", attachments: [MessageList.Message.Attachment(contentType: "test", filename: "test", url: URL(string: "https://example.com")!, size: nil)],
                    sender: MessageList.Message.Sender(id: "def456", name: "Testy McTestface", profilePhotoURL: URL(string: "https://example.com")), sentDate: Date(), sentByLocalUser: true, isAutomated: true, isHidden: true)
            ], endsWith: nil, hasMore: true)
        let messageManager = MessageManager()
        messageManager.messageList = messageList

        messageManager.messageListSaver = MessageManager.createSaver(containerURL: containerURL, filename: CurrentLoader.messagesFilename, fileManager: MockEnvironment().fileManager)
        try messageManager.saveMessagesToDisk()
        messageManager.messageList = nil

        let loader = CurrentLoader(containerURL: containerURL, environment: MockEnvironment())
        let loadedMessages = try loader.loadMessages()

        XCTAssertEqual(messageList.messages.count, loadedMessages?.messages.count)
    }

    func testGetMessage() {
        let messageList = MessageList(
            messages: [
                MessageList.Message(
                    id: "abc123", body: "test", attachments: [MessageList.Message.Attachment(contentType: "test", filename: "test", url: URL(string: "https://example.com")!, size: nil)],
                    sender: MessageList.Message.Sender(id: "def456", name: "Testy McTestface", profilePhotoURL: URL(string: "https://example.com")), sentDate: Date(), sentByLocalUser: true, isAutomated: true, isHidden: true)
            ], endsWith: nil, hasMore: true)

        self.spySender?.messageManager.messageList = messageList

        self.spySender?.getMessages(completion: { messageManager in
            XCTAssertEqual(messageManager.messageList?.messages[0].body, "test")
        })
    }

    func testSendMessage() throws {
        self.viewModel?.messageBody = "Test"

        try self.viewModel?.sendMessage()

        XCTAssertEqual(self.spySender?.message, OutgoingMessage(body: "Test"))
    }
    
    @available(iOS 13.0, *)
    func testAddImageAttachment() throws {
        let image = UIImage.init(systemName: "doc")!
        let queue = DispatchQueue(label: "AddImage")
        self.viewModel?.messageBody = "Test"
        try queue.sync {
            try self.viewModel?.addImageAttachment(image)
        }
    }
}
