## Installation

[![NPM](https://nodei.co/npm/h2o.js.png?compact=true)](https://npmjs.org/package/h2o.js)

This Node.js / io.js module provides access to the [H<sub>2</sub>O](http://h2o.ai) JVM (and extensions thereof), its objects, its machine-learning algorithms, and modeling support (basic munging and feature generation) capabilities.

It is designed to bring H<sub>2</sub>O to a wider audience of data and machine learning devotees that work exclusively with Javascript, for building machine learning applications or doing data munging in a fast, scalable environment without any extra mental anguish about threads and parallelism.

H<sub>2</sub>O also supports R, Python, Scala and Java.

## What is H<sub>2</sub>O?

H<sub>2</sub>O is a piece of Java software for data modeling and general computing. There are many different views of the H<sub>2</sub>O software, but the primary view of H<sub>2</sub>O is that of a distributed (many machines), parallel (many CPUs), in memory (several hundred GBs Xmx) processing engine.

There are two levels of parallelism:

- within node
- across (or between) node.

The goal, remember, is to "simply" add more processors to a given problem in order to produce a solution faster. The conceptual paradigm MapReduce (also known as "divide and conquer and combine") along with a good concurrent application structure (c.f. [jsr166y](http://gee.cs.oswego.edu/dl/jsr166/dist/jsr166ydocs/) and [NonBlockingHashMap](http://www.cs.rice.edu/~javaplt/javadoc/concjunit4.7/org/cliffc/high_scale_lib/NonBlockingHashMap.html)) enable this type of scaling in H<sub>2</sub>O (we’re really cooking with gas now!).

For application developers and data scientists, the gritty details of thread-safety, algorithm parallelism, and node coherence on a network are concealed by simple-to-use REST calls that are all documented here. In addition, H<sub>2</sub>O is an [open-source project](https://github.com/h2oai/h2o-dev) under the Apache v2 licence. All of the source code is on [Github](https://github.com/h2oai/), there is an [active Google Group mailing list](https://groups.google.com/d/forum/h2ostream), our [nightly tests](http://test.h2o.ai/) are open for perusal, our [JIRA ticketing system](https://0xdata.atlassian.net/secure/Dashboard.jspa) is also open for public use. Last, but not least, we regularly engage the machine learning community all over the nation with a [very busy meetup schedule](http://h2o.ai/events/) (so if you’re not in The Valley, no sweat, we’re probably coming to you soon!), and finally, we host our very own [H<sub>2</sub>O World](http://h2o.ai/h2o-world/) conference. We also sometimes host hack-a-thons at our campus in Mountain View, CA. Needless to say, there is a lot of support for the application developer.

In order to make the most out of H<sub>2</sub>O, there are some key conceptual pieces that are helpful to know before getting started. Mainly, it’s helpful to know about the different types of objects that live in H<sub>2</sub>O and what the rules of engagement are in the context of the REST API (which is what any non-JVM interface is all about).

Let’s get started!

## The H<sub>2</sub>O Object System

H<sub>2</sub>O sports a distributed key-value store (the "DKV"), which contains pointers to the various objects that make up the H<sub>2</sub>O ecosystem. The DKV is a kind of biosphere in that it encapsulates all shared objects (though, it may not encapsulate all objects). Some shared objects are mutable by the client; some shared objects are read-only by the client, but mutable by H<sub>2</sub>O (e.g. a model being constructed will change over time); and actions by the client may have side-effects on other clients (multi-tenancy is not a supported model of use, but it is possible for multiple clients to attach to a single H<sub>2</sub>O cloud).

Briefly, these objects are:

- **Key**: A key is an entry in the DKV that maps to an object in H<sub>2</sub>O.
- **Frame**: A Frame is a collection of Vec objects. It is a 2D array of elements.
- **Vec**: A Vec is a collection of Chunk objects. It is a 1D array of elements.
- **Chunk**: A Chunk holds a fraction of the BigData. It is a 1D array of elements.
- **ModelMetrics**: A collection of metrics for a given category of model.
- **Model**: A model is an immutable object having predict and metrics methods.
- **Job**: A Job is a non-blocking task that performs a finite amount of work.

Many of these objects have no meaning to an end Javascript user, but in order to make sense of the objects available in this module it is helpful to understand how these objects map to objects in the JVM (because after all, this module is an interface that allows the manipulation of a distributed system).

(To be continued...)
