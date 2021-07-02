# Appleseed

From the [reference implementation](https://github.com/cblgh/appleseed-metric): 

> Appleseed is a trust propagation algorithm and trust metric for local group trust computation. It was first described by Cai-Nicolas Ziegler and Georg Lausen in [Propagation Models for Trust and Distrust in Social Networks](https://link.springer.com/article/10.1007/s10796-005-4807-3).
>
> Basically, Appleseed makes it possible to take a group of nodeswhich have various trust relations to each otherlook at the group from the perspective of a single node, and rank each of the other nodes according to how trusted they are from the perspective of the single node. 
> 
> Appleseed is used by [TrustNet](https://github.com/cblgh/trustnet), a system for interacting with and managing computational trust.
> 
> For more details, see [Chapter 6 of the TrustNet report](https://cblgh.org/dl/trustnet-cblgh.pdf#section.6.1) by Alexander Cobleigh. The report contains a full walkthrough of the original algorithm's pseudocode, a legend over all of the variables, and water-based analogy for understanding the otherwise abstract algorithm (and illustrations!) You may also be interested in reading the [blog article](https://cblgh.org/articles/trustnet.html) introducing TrustNet.

## Api

All memory is managed entirely by the library user. Be sure to reset all the `Node`s in the graph between each call of `appleseed`.

Also, the reference implementation does some additional processing on the data after the main algorithm completes. In this implementation, that is considered out of scope.

## License

This code is licensed under the Affero GNU General Public License (AGPL), version 3 or later, as a derivative work of the reference implementation.
The reference implementation is dual-licensed. If you work out a licensing deal with the original author, and wish to use the Zig implementation, please contact me.
