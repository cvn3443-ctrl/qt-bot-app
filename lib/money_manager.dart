class MoneyManager {
  final double baseStake;
  final int maxConsecutiveDoubles;
  final double dailyLossCap;
  double currentStake;
  int consecutiveLosses = 0;
  double dailyLoss = 0;

  MoneyManager({required this.baseStake, required this.dailyLossCap, this.maxConsecutiveDoubles = 4})
      : currentStake = baseStake;

  bool get stoppedForToday => dailyLoss >= dailyLossCap;

  void recordResult(bool won, double amountRisked) {
    if (won) {
      currentStake = baseStake;
      consecutiveLosses = 0;
    } else {
      dailyLoss += amountRisked;
      consecutiveLosses++;
      currentStake = (consecutiveLosses >= maxConsecutiveDoubles) ? baseStake : currentStake * 2;
      if (consecutiveLosses >= maxConsecutiveDoubles) consecutiveLosses = 0;
    }
  }

  void resetDaily() => dailyLoss = 0;
}
