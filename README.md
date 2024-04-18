# Project 3: Chord - P2P System and Simulation
This project aims to simulate the Chord protocol implementing the Scalable Key Lookup using the actor model in Erlang.
### Authors:
* Vaibhavi Deshpande
* Ishan Kunkolikar
### Pre-requisites:
* Erlang/OTP version - 25.1
### Steps to run:
Commands to start the algorithm:
``` 
c(chord).
chord : start_main_process ( number_of_nodes, number_of_requests ).
```
Where ‘number_of_nodes’ is the number of nodes to be created in the peer-to-peer system and ‘number_of_requests’ is the number of requests that each node has to make.

### What is working?
* Creating the Chord Ring and Fixing Finger Tables:
According to the number of nodes received in the input, the chord ring is created by spawning each peer actor/node and each node is assigned a key using consistent hashing enabling the nodes to join the network. Every node maintains its successor node, predecessor nodes, and finger tables which are stabilized and fixed periodically. The information stored in the finger table should be updated periodically as different nodes join the system.
* Requests Lookup using Scalable Key Lookup and Find Successor:
Once the chord ring is created, every node randomly generates a request according to the input received. For any request generated, the node searches the finger table using find_successor in accordance with the algorithm from the paper which returns the successor node if the node to lookup is between that node and the successor otherwise it searches for the node whose ID most immediately precedes the ID of the node which is requested and it generates a request to that node.
* Average Hop Count: The average hop is calculated after every node in the system completes the specified number of requests from the input value.

### Chord Algorithm:

### Construction of the Chord ring
* Hash function assigns each node and key an m-bit identifier using a base hash function such as SHA-1
  * ID(node) = hash(IP, Port)
  * ID(key) = hash(key)
  * Both are uniformly distributed
  * Both exist in the same ID space
* Properties of consistent hashing:
  * Function balances load: all nodes receive roughly the same number of keys
  * When an Nth node joins (or leaves) the network, only an O(1/N) fraction of the keys are moved to a different location
* Identifiers are arranged on a identifier circle modulo 2 => Chord ring
* A key k is assigned to the node whose identifier is equal to or greater than the key‘s identifier
* This node is called successor(k) and is the first node clockwise from k.

### Scalable node localization:
* Additional routing information to accelerate lookups
* Each node n contains a routing table with up to m entries (m: number of bits of the identifiers) => finger table
* i<sup>th</sup> entry in the table at node n contains the first node s that succeds n by at least 2 <sup>i - 1</sup>
* s = successor (n + 2<sup>i - 1</sup> )
* s is called the i finger of node n
* Important characteristics of this scheme:
    * Each node stores information about only a small number of nodes (m)
    * Each nodes knows more about nodes closely following it than about nodes farer away
    * A finger table generally does not contain enough information to directly determine the successor of an arbitrary key k

### Node joins and stabilization:
* To ensure correct lookups, all successor pointers must be up to date
* => stabilization protocol running periodically in the background
* Updates finger tables and successor pointers
* Stabilization protocol:
    * Stabilize(): n asks its successor for its predecessor p and decides whether p should be n‘s successor instead (this is the case if p recently joined the system).
    * Notify(): notifies n‘s successor of its existence, so it can change its predecessor to n
    * Fix_fingers(): updates finger tables

### Impact of node joins on lookups:
* All finger table entries are correct => O(log N) lookups
* Successor pointers correct, but fingers inaccurate => correct but slower lookups
* Stabilization completed => no influence on performence
* Only for the negligible case that a large number of nodes joins between the target‘s predecessor and the target, the lookup is slightly slower
* No influence on performance as long as fingers are adjusted faster than the network doubles in size




### Largest network
* Maximum number of nodes: 4000
* Maximum number of requests: 10 * 4000 = 40,000
