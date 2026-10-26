import test from 'node:test';
import assert from 'node:assert/strict';
import { classifyResponsePerformance } from '../services/landlord_response_metrics.js';
test('response labels require a minimum sample', () => {
    assert.equal(classifyResponsePerformance({
        totalValidInquiries: 1,
        answeredInquiries: 1,
        averageFirstResponseMinutes: 1,
        previousAverageFirstResponseMinutes: null,
        previousAnsweredInquiries: 0,
    }), 'response_activity_building');
});
test('fast and quick labels use actual average first-response times', () => {
    const baseline = {
        totalValidInquiries: 5,
        answeredInquiries: 5,
        previousAverageFirstResponseMinutes: null,
        previousAnsweredInquiries: 0,
    };
    assert.equal(classifyResponsePerformance({
        ...baseline,
        averageFirstResponseMinutes: 4,
    }), 'lightning_fast');
    assert.equal(classifyResponsePerformance({
        ...baseline,
        averageFirstResponseMinutes: 12,
    }), 'quick_responder');
});
test('sustained slow replies receive a needs-improvement label with enough data', () => {
    assert.equal(classifyResponsePerformance({
        totalValidInquiries: 6,
        answeredInquiries: 6,
        averageFirstResponseMinutes: 75,
        previousAverageFirstResponseMinutes: null,
        previousAnsweredInquiries: 0,
    }), 'needs_improvement');
});
test('needs-improvement and getting-faster labels are mutually exclusive', () => {
    assert.equal(classifyResponsePerformance({
        totalValidInquiries: 8,
        answeredInquiries: 3,
        averageFirstResponseMinutes: 30,
        previousAverageFirstResponseMinutes: 90,
        previousAnsweredInquiries: 4,
    }), 'needs_improvement');
    assert.equal(classifyResponsePerformance({
        totalValidInquiries: 8,
        answeredInquiries: 8,
        averageFirstResponseMinutes: 30,
        previousAverageFirstResponseMinutes: 45,
        previousAnsweredInquiries: 8,
    }), 'getting_faster');
});
test('high unanswered share takes precedence over a fast average', () => {
    assert.equal(classifyResponsePerformance({
        totalValidInquiries: 8,
        answeredInquiries: 3,
        averageFirstResponseMinutes: 4,
        previousAverageFirstResponseMinutes: null,
        previousAnsweredInquiries: 0,
    }), 'needs_improvement');
});
//# sourceMappingURL=landlord_response_metrics.test.js.map