const test = require('node:test');
const assert = require('node:assert/strict');

const { sortRankings, toRankingAverage } = require('./ranking');

test('sortRankings uses reviewCount when displayed average ties', () => {
  const rankings = [
    {
      restaurantName: 'Ristorante 1',
      averageRating: 7.49,
      reviewCount: 2
    },
    {
      restaurantName: 'Ristorante 2',
      averageRating: 7.51,
      reviewCount: 5
    }
  ];

  const ordered = rankings
    .map(ranking => ({
      ...ranking,
      averageRating: toRankingAverage(ranking.averageRating)
    }))
    .sort(sortRankings);

  assert.deepEqual(
    ordered.map(ranking => ranking.restaurantName),
    ['Ristorante 2', 'Ristorante 1']
  );
  assert.deepEqual(
    ordered.map(ranking => ranking.averageRating),
    [7.5, 7.5]
  );
});

test('sortRankings falls back to restaurant name for identical score and review count', () => {
  const rankings = [
    {
      restaurantName: 'Zeta',
      averageRating: 8,
      reviewCount: 3
    },
    {
      restaurantName: 'Alfa',
      averageRating: 8,
      reviewCount: 3
    }
  ];

  const ordered = rankings.sort(sortRankings);

  assert.deepEqual(
    ordered.map(ranking => ranking.restaurantName),
    ['Alfa', 'Zeta']
  );
});