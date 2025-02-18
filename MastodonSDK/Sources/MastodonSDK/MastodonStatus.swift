// Copyright © 2023 Mastodon gGmbH. All rights reserved.

import Foundation
import Combine
import CoreDataStack

public final class MastodonStatus: ObservableObject {
    public typealias ID = Mastodon.Entity.Status.ID
    
    /// `originalStatus` is used to restore a previously re-blogged state when a status
    /// has been originally reblogged by another account
    @Published public var originalStatus: MastodonStatus?
    
    @Published public var entity: Mastodon.Entity.Status
    @Published public var reblog: MastodonStatus?
    
    @Published public var isSensitiveToggled: Bool = false
    
    @Published public var poll: MastodonPoll?
    
    init(entity: Mastodon.Entity.Status, isSensitiveToggled: Bool) {
        self.entity = entity
        self.isSensitiveToggled = isSensitiveToggled
        
        if let poll = entity.poll {
            self.poll = .init(poll: poll, status: self)
        }
        
        if let reblog = entity.reblog {
            self.reblog = MastodonStatus.fromEntity(reblog)
        } else {
            self.reblog = nil
        }
    }
    
    public var id: ID {
        entity.id
    }
}

extension MastodonStatus {
    public static func fromEntity(_ entity: Mastodon.Entity.Status) -> MastodonStatus {
        return MastodonStatus(entity: entity, isSensitiveToggled: false)
    }
    
    public func inheritSensitivityToggled(from status: MastodonStatus?) -> MastodonStatus {
        self.isSensitiveToggled = status?.isSensitiveToggled ?? false
        self.reblog?.isSensitiveToggled = status?.reblog?.isSensitiveToggled ?? false
        return self
    }
    
    public func withOriginal(status: MastodonStatus?) -> MastodonStatus {
        originalStatus = status
        return self
    }
    
    public func withPoll(_ poll: MastodonPoll?) -> MastodonStatus {
        self.poll = poll
        return self
    }
}

extension MastodonStatus: Hashable {
    public static func == (lhs: MastodonStatus, rhs: MastodonStatus) -> Bool {
        lhs.entity == rhs.entity &&
        lhs.poll == rhs.poll &&
        lhs.entity.poll == rhs.entity.poll &&
        lhs.reblog?.entity == rhs.reblog?.entity &&
        lhs.reblog?.poll == rhs.reblog?.poll &&
        lhs.reblog?.entity.poll == rhs.reblog?.entity.poll &&
        lhs.isSensitiveToggled == rhs.isSensitiveToggled &&
        lhs.reblog?.isSensitiveToggled == rhs.reblog?.isSensitiveToggled
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(entity)
        hasher.combine(poll)
        hasher.combine(reblog?.entity)
        hasher.combine(reblog?.poll)
        hasher.combine(isSensitiveToggled)
        hasher.combine(reblog?.isSensitiveToggled)
    }
}

public extension Mastodon.Entity.Status {
    var asMastodonStatus: MastodonStatus {
        .fromEntity(self)
    }
    
    var mastodonVisibility: MastodonVisibility? {
        guard let visibility = visibility?.rawValue else { return nil }
        return MastodonVisibility(rawValue: visibility)
    }
}

public extension MastodonStatus {
    enum UpdateIntent {
        case bookmark(Bool)
        case reblog(Bool)
        case favorite(Bool)
        case toggleSensitive(Bool)
        case delete
        case edit
        case pollVote
    }
}

public extension MastodonStatus {
    func getPoll(in domain: String, authorization: Mastodon.API.OAuth.Authorization) async -> Mastodon.Entity.Poll? {
        guard
            let pollId = entity.poll?.id
        else { return nil }
        let poll = try? await Mastodon.API.Polls.poll(session: .shared, domain: domain, pollID: pollId, authorization: authorization).singleOutput().value
        return poll
    }
}
