function toRankingAverage(rawAverage) {
  if (typeof rawAverage !== 'number' || Number.isNaN(rawAverage)) {
    return 0;
  }

  return Math.round(rawAverage * 4) / 4;
}

function sortRankings(left, right) {
  const averageDiff = toRankingAverage(right.averageRating) - toRankingAverage(left.averageRating);

  if (averageDiff !== 0) {
    return averageDiff;
  }

  const reviewCountDiff = (right.reviewCount || 0) - (left.reviewCount || 0);

  if (reviewCountDiff !== 0) {
    return reviewCountDiff;
  }

  return (left.restaurantName || '').localeCompare(right.restaurantName || '');
}

module.exports = {
  toRankingAverage,
  sortRankings
};