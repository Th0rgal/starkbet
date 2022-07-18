<h1 align="center">
  <br>
  <img src="/logo.png?raw=true" alt="Shut Up and Take my Money" width="256">
  <br>
</h1>

<h4 align="center">💵 Decentralized betting</h4>

## What is StarkBet
Starkbet is a project built for Encode x Starknet 2022 Hackathon. It allows to bet on future data values provided by Empiric Network Oracle using any ERC20. Let's take an example. If you are sure that the price of bitcoin in US dollars will be over $20,000 in a week, you can take that bet with let's say 1 ether and keep it open for other participants for a day. If you are right, you will receive the losers' share of the bet in proportion to your bet among the total winners. This can be used to make much more exotic bets, for example on the weather in Paris in 7 months. 

## What is the purpose of this?
For bettors, the benefit is exposure to things that are not easy to get exposed too.
For informed or competent people, able to estimate the probability that the temperature in Paris will exceed 28 degrees in 7 months for example, it is a way to make money.
For everyone else, it's a way to tap into the wisdom of the markets to get forecasts.

## How does it work?
Anyone can play for or against a condition on a data stream provided by the Oracle with a certain end date of the bet, and a result date by betting any token. People playing with the same condition, the same date and betting the same token will split each other's tokens on the expiration date if their prediction on the condition was correct.

## What can be improved?
The first thing is that sometimes the ratio of reward received by a person does not fall right: this makes some undivided token dust that is kept by the protocol, lost forever. They could be used to create incentives, to close a bet as soon as it expires for example.
The second thing is liquidity. We would like to allow people to transfer their position in the bet before it expires. This would increase liquidity and correct the price as you get closer to the expiration date.