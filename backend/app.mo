import HashMap "mo:base/HashMap";
import Text "mo:base/Text";
import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import Int "mo:base/Int";
import Result "mo:base/Result";
import Array "mo:base/Array";
import Iter "mo:base/Iter";
import Time "mo:base/Time";

actor MemoryChain {
    // Tipe data untuk kenangan
    type Memory = {
        id: Nat;
        creator: Principal;
        title: Text;
        description: Text;
        emotionalIntensity: Nat8; // 1-10
        tags: [Text];
        timestamp: Int;
        verificationStatus: VerificationStatus;
        collaborators: [Principal];
        memoryTokens: Nat;
    };

    // Status verifikasi kenangan
    type VerificationStatus = {
        #Unverified;
        #PartiallyVerified;
        #FullyVerified;
    };

    // Tipe data kolaborasi kenangan
    type MemoryCollaboration = {
        memoryId: Nat;
        collaborator: Principal;
        contribution: Text;
        verified: Bool;
    };

    // Penyimpanan kenangan
    private var memories = HashMap.HashMap<Nat, Memory>(10, Nat.equal, Nat.hash);
    private var memoryCollaborations = HashMap.HashMap<Nat, [MemoryCollaboration]>(10, Nat.equal, Nat.hash);
    private var memoryCounter : Nat = 0;

    // Membuat kenangan baru
    public shared(msg) func createMemory(
        title: Text, 
        description: Text,
        emotionalIntensity: Nat8,
        tags: [Text]
    ) : async Result.Result<Nat, Text> {
        // Validasi input
        if (emotionalIntensity < 1 or emotionalIntensity > 10) {
            return #err("Emotional intensity must be between 1-10");
        };

        let newMemory : Memory = {
            id = memoryCounter;
            creator = msg.caller;
            title = title;
            description = description;
            emotionalIntensity = emotionalIntensity;
            tags = tags;
            timestamp = Time.now();
            verificationStatus = #Unverified;
            collaborators = [];
            memoryTokens = 1;
        };

        memories.put(memoryCounter, newMemory);
        memoryCounter += 1;
        #ok(memoryCounter - 1)
    };

    // Kolaborasi kenangan
    public shared(msg) func collaborateOnMemory(
        memoryId: Nat,
        contribution: Text
    ) : async Result.Result<MemoryCollaboration, Text> {
        switch (memories.get(memoryId)) {
            case null { return #err("Memory not found"); };
            case (?memory) {
                let collaboration : MemoryCollaboration = {
                    memoryId = memoryId;
                    collaborator = msg.caller;
                    contribution = contribution;
                    verified = false;
                };

                // Update kolaborasi
                switch (memoryCollaborations.get(memoryId)) {
                    case null { 
                        memoryCollaborations.put(memoryId, [collaboration]); 
                    };
                    case (?existingCollaborations) {
                        memoryCollaborations.put(memoryId, 
                            Array.append(existingCollaborations, [collaboration])
                        );
                    };
                };

                // Update memori
                let updatedMemory : Memory = {
                    id = memory.id;
                    creator = memory.creator;
                    title = memory.title;
                    description = memory.description;
                    emotionalIntensity = memory.emotionalIntensity;
                    tags = memory.tags;
                    timestamp = memory.timestamp;
                    verificationStatus = #PartiallyVerified;
                    collaborators = 
                        Array.append(memory.collaborators, [msg.caller]);
                    memoryTokens = memory.memoryTokens + 1;
                };

                memories.put(memoryId, updatedMemory);
                #ok(collaboration)
            };
        }
    };

    // Verifikasi kolaborasi
    public shared(msg) func verifyCollaboration(
        memoryId: Nat,
        collaboratorId: Principal
    ) : async Result.Result<MemoryCollaboration, Text> {
        switch (memories.get(memoryId)) {
            case null { return #err("Memory not found"); };
            case (?memory) {
                // Hanya pembuat memori yang bisa verifikasi
                if (memory.creator != msg.caller) {
                    return #err("Only memory creator can verify");
                };

                switch (memoryCollaborations.get(memoryId)) {
                    case null { return #err("No collaborations found"); };
                    case (?collaborations) {
                        let updatedCollaborations = 
                            Array.map(collaborations, func(collab: MemoryCollaboration) : MemoryCollaboration {
                                if (collab.collaborator == collaboratorId) {
                                    { 
                                        memoryId = collab.memoryId;
                                        collaborator = collab.collaborator;
                                        contribution = collab.contribution;
                                        verified = true 
                                    }
                                } else collab;
                            });

                        memoryCollaborations.put(memoryId, updatedCollaborations);

                        // Update status memori jika semua kolaborasi terverifikasi
                        let allVerified = 
                            Array.all(updatedCollaborations, func(collab: MemoryCollaboration) : Bool { 
                                collab.verified 
                            });

                        if (allVerified) {
                            let updatedMemory : Memory = {
                                ...memory;
                                verificationStatus = #FullyVerified;
                                memoryTokens = memory.memoryTokens + 5;
                            };
                            memories.put(memoryId, updatedMemory);
                        };

                        // Temukan kolaborasi yang diverifikasi
                        let verifiedCollab = 
                            Array.find(updatedCollaborations, func(collab: MemoryCollaboration) : Bool { 
                                collab.collaborator == collaboratorId 
                            });

                        switch (verifiedCollab) {
                            case null { return #err("Collaboration not found"); };
                            case (?collab) { #ok(collab) };
                        }
                    };
                }
            };
        }
    };

    // Dapatkan detail kenangan
    public query func getMemoryDetails(memoryId: Nat) : async ?Memory {
        memories.get(memoryId)
    };

    // Dapatkan kolaborasi kenangan
    public query func getMemoryCollaborations(memoryId: Nat) : async [MemoryCollaboration] {
        switch (memoryCollaborations.get(memoryId)) {
            case null { [] };
            case (?collaborations) { collaborations };
        }
    };
}
