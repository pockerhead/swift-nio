//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2017-2024 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//
import NIOCore

/// A simple `ChannelHandler` that catches protocol errors emitted by the
/// `WebSocketFrameDecoder` and automatically generates protocol error responses.
///
/// This `ChannelHandler` provides default error handling for basic errors in the
/// WebSocket protocol, and can be used by users when custom behaviour is not required.
public final class WebSocketProtocolErrorHandler: ChannelInboundHandler {
    public typealias InboundIn = Never
    public typealias OutboundOut = WebSocketFrame

    /// Indicate that this `ChannelHandeler` is used by a WebSocket server or client. Default is true.
    private let isServer: Bool

    public init() {
        self.isServer = true
    }

    /// Initialize this `ChannelHandler` to be used by a WebSocket server or client.
    ///
    /// - Parameters:
    ///     - isServer: indicate whether this `ChannelHandler` is used by a WebSocket server or client.
    public init(isServer: Bool) {
        self.isServer = isServer
    }

    public func errorCaught(context: ChannelHandlerContext, error: Error) {
        let loopBoundContext = context.loopBound
        if let error = error as? NIOWebSocketError {
            var data = context.channel.allocator.buffer(capacity: 2)
            data.write(webSocketErrorCode: WebSocketErrorCode(error))
            let frame = WebSocketFrame(
                fin: true,
                opcode: .connectionClose,
                maskKey: self.makeMaskingKey(),
                data: data
            )
            context.writeAndFlush(Self.wrapOutboundOut(frame)).whenComplete { (_: Result<Void, Error>) in
                let context = loopBoundContext.value
                context.close(promise: nil)
            }
        }

        // Regardless of whether this is an error we want to handle or not, we always
        // forward the error on to let others see it.
        context.fireErrorCaught(error)
    }

    private func makeMaskingKey() -> WebSocketMaskingKey? {
        // According to RFC 6455 Section 5, a client *must* mask all frames that it sends to the server.
        // A server *must not* mask any frames that it sends to the client
        self.isServer ? nil : .random()
    }
}

@available(*, unavailable)
extension WebSocketProtocolErrorHandler: Sendable {}
