// Generated by CoffeeScript 1.9.1
(function() {
  var h2o, h2ojs, test;

  h2ojs = require('./../h2o.js');

  test = require('tape');

  h2o = h2ojs.connect();

  test('getClusterStatus', function(t) {
    return h2o.getClusterStatus(function(error, cluster) {
      if (error) {
        return t.end(error);
      } else {
        console.log('Cluster information:');
        h2o.dump(cluster);
        return t.end();
      }
    });
  });

  test('getTimeline', function(t) {
    return h2o.getTimeline(function(error, timeline) {
      if (error) {
        return t.end(error);
      } else {
        console.log('Timeline information:');
        h2o.dump(timeline);
        return t.end();
      }
    });
  });

  test('getStackTrace', function(t) {
    return h2o.getStackTrace(function(error, stackTrace) {
      if (error) {
        return t.end(error);
      } else {
        console.log('Current stack trace:');
        h2o.dump(stackTrace);
        return t.end();
      }
    });
  });

  test('getLogFile', function(t) {
    return h2o.getLogFile(-1, 'info', function(error, logFile) {
      if (error) {
        return t.end(error);
      } else {
        console.log('Log file:');
        h2o.dump(logFile);
        return t.end();
      }
    });
  });

  test('runProfiler', function(t) {
    return h2o.runProfiler(10, function(error, result) {
      if (error) {
        return t.end(error);
      } else {
        console.log('Profiler output:');
        h2o.dump(result);
        return t.end();
      }
    });
  });

  test('runNetworkTest', function(t) {
    return h2o.runNetworkTest(function(error, result) {
      if (error) {
        return t.end(error);
      } else {
        console.log('Network test output:');
        h2o.dump(result);
        return t.end();
      }
    });
  });

  test('about', function(t) {
    return h2o.about(function(error, about) {
      if (error) {
        return t.end(error);
      } else {
        console.log('About H2O:');
        h2o.dump(about);
        return t.end();
      }
    });
  });

}).call(this);