# Aleo Lottery Program

This is a decentralized lottery system built on Aleo that demonstrates the use of records, structs, mappings, transitions, and the async/await model. This allows users to participate in a lottery by buying tickets with tokens, submitting random seeds for the drawing, and claiming prizes if they win.

## in detail

- Lottery Creation (create_lottery)

  - The program ensures that prize_amount > 0, max_parts > 0, and ticket_price > 0 using assert statements, preventing the creation of invalid lotteries.
  - It uses Mapping::contains(lottery_data, lottery_id) to prevent duplication with existing lotteries, ensuring consistency when creating new lotteries.

- Ticket Purchase (buy_ticket)

  - Payment is processed using payment.token, and within verify_and_update_account, the program retrieves lottery details and validates that the expected_price (equal to ticket.amount) matches info.ticket_price using assert_eq(expected_price, info.ticket_price).
  - The assertion ensures that tickets cannot be purchased at prices other than the one set in the lottery. If a user tries to change the purchase amount, the assertion will trigger an error.
  - Any excess payment is returned to the user as a remainder record. Additionally, the user's balance is updated in the account mapping, ensuring that the user only pays the actual ticket price.

- Ticket Registration (register_ticket)

  - register_ticket calls update_ticket_info, which:
    - Checks if a seed has been submitted (assert(seed_done)).
    - Ensures the maximum number of participants is not exceeded (assert(current_count < max_parts)).
    - Confirms consistency between amount and info.ticket_price using assertions during the register_ticket call.
  - Validates that info.is_drawn is false, ensuring tickets cannot be registered after the lottery has been drawn.

- Seed Submission (submit_seed)

  - The program confirms that submission_ended is false and checks has_submitted and current_count < max_parts.
  - Submitted seeds are hashed and added to combined_seed_hash, contributing to the source of randomness for the drawing.

- Submission Closing (end_submission_phase)

  - This function can only be executed by the admin (validated via an admin check). It sets submission_ended to true, preventing further seed submissions after this point.

- Drawing the Winner (draw_winner)

  - Only the admin can execute draw_winner (checked via check_admin_and_draw with assert_eq(caller, admin)).
  - The program validates that submission_ended is true, info.is_drawn is false, and there are participants (total_tickets > 0).
  - The height_val is reduced to reduced_height = height_val % 10000u32 for entropy reduction, and the resulting height_hash is combined with combined_seed_hash to generate a random value. This is because in the basic_lottery_v3 implementation, there was an overflow issue when hashing the block height as a u64 value. To prevent this, the block height (height_val) is reduced using height_val % 10000u32 before hashing, ensuring no overflow occurs and improving entropy for randomness generation. This refinement enhances the reliability of the lottery system's randomness.
  - A winner is determined from the random value, and the winning ticket number is saved in winner_ticket. Afterward, info.is_drawn is set to true.
  - This logic ensures that only the admin can draw the lottery, and after drawing, participants can claim their prizes.

- Prize Claiming (claim_prize)
  - The user must own the ticket (assert_eq(ticket.owner, self.caller)).
  - verify_and_update_state retrieves the prize amount and verifies that the assigned_number matches the winner_number.
  - It prevents double claiming through the prize_claimed check.
  - The prize amount is added to the user's balance in the account mapping. Additionally, a record(token) is returned to allow the user to confirm their prize claim.

# Deployment Information

- Program ID: basic_lottery_v4.aleo
- Signature: at1pvqzfkha8f3wfsa7q6ywew3rfazleytfchkrm9uxwwdfl8vdyq8qha9wxy
  (https://testnet.aleoscan.io/transaction?id=at1pvqzfkha8f3wfsa7q6ywew3rfazleytfchkrm9uxwwdfl8vdyq8qha9wxy)
- Network: Aleo Testnet

# Program Flow

1. Admin mints tokens to participants
2. Admin creates a lottery with specified parameters
3. Participants buy tickets using tokens
4. Participants submit random seeds
5. Participants register their tickets
6. Admin ends the submission phase
7. Admin conducts the lottery drawing
8. Winner claims their prize

# Accounts using the following tests

- Account A:

  - Private Key: APrivateKey1zkpHL8rPwuLVu94Qh5mFmaFFVgoMBa8vhvBPJo1g4WtYpmL
  - View Key: AViewKey1fJcLCh46bF4424ScReuiiX5YpYjVBg9N1a5KiWkS8UXc
  - Address: aleo16p0lgtzcsl0u86yd744pdu5nnnt5a23amaa9w8zecsge3v3sncxsk9lpm5

- Account B:

  - Private Key: APrivateKey1zkpDM51iGRkHCWMGweKwgDiKSqztCCSYiz7UnpWoyt1eouX
  - View Key: AViewKey1ubsGVQyWhbRmvSrTPNVp1rT1TQqFjn9bFfvVXmEM9h4M
  - Address: aleo1t3ut4l0wnaf3rrkt7djtm0fflvl2tzhhm4jfyyxt0w2a35823v8q48y9t8

- Account C:
  - Private Key: APrivateKey1zkpAY3kFSAreD8aVMJ4CEjimgT3TgQhAHLEU8hxme98ECST
  - View Key: AViewKey1gtJuMXyz9yKwbi3RjbsKL1LWJYuJS8efjPCEaHsAmZnb
  - Address: aleo12r9q2j3zutks9ypcdmhhanjlrry7mdwkn2zf055scher4yr4n5rsz6lkf7

# Local Testing

1. Admin mits tokens (mint_public)

```
# Admin environment setup
echo "
NETWORK=testnet
PRIVATE_KEY=<YOUR_PRIVATE_KEY>
ENDPOINT=https://api.explorer.provable.com/v1
" > .env

# Admin mints tokens to participants
# mint_public(receiver, amount)
leo run mint_public aleo16p0lgtzcsl0u86yd744pdu5nnnt5a23amaa9w8zecsge3v3sncxsk9lpm5 100u64
leo run mint_public aleo1t3ut4l0wnaf3rrkt7djtm0fflvl2tzhhm4jfyyxt0w2a35823v8q48y9t8 100u64
leo run mint_public aleo12r9q2j3zutks9ypcdmhhanjlrry7mdwkn2zf055scher4yr4n5rsz6lkf7 100u64
```

2. Admin setups a loto（create_lottery）

```
# create_lottery(lottery_id, decription, prize_amount, max_parts, ticket_price)
leo run create_lottery 12345field 20241219field 100u64 3u64 60u64
```

3. Participants purchase tickets (buy_ticket) ⇒ submit seeds (submit_seed) ⇒ register tickets (register_ticket)

```
# Account A
echo "
NETWORK=testnet
PRIVATE_KEY=APrivateKey1zkpHL8rPwuLVu94Qh5mFmaFFVgoMBa8vhvBPJo1g4WtYpmL
ENDPOINT=https://api.explorer.provable.com/v1
" > .env

leo run buy_ticket 12345field "{
  owner: aleo16p0lgtzcsl0u86yd744pdu5nnnt5a23amaa9w8zecsge3v3sncxsk9lpm5.private,
  amount: 100u64.private,
  _nonce: 4190734422767811719234227078739225890557251337147506639477471553729138704762group.public
}" 60u64

leo run submit_seed 12345field 17field

leo run register_ticket 12345field "{
  owner: aleo16p0lgtzcsl0u86yd744pdu5nnnt5a23amaa9w8zecsge3v3sncxsk9lpm5.private,
  lottery_id: 12345field.private,
  amount: 60u64.private,
  _nonce: 8005958516899389536474238535840701346517318980714755791027791016659541107081group.public
}" 60u64


# Account B
echo "
NETWORK=testnet
PRIVATE_KEY=APrivateKey1zkpDM51iGRkHCWMGweKwgDiKSqztCCSYiz7UnpWoyt1eouX
ENDPOINT=https://api.explorer.provable.com/v1
" > .env

leo run buy_ticket 12345field "{
  owner: aleo1t3ut4l0wnaf3rrkt7djtm0fflvl2tzhhm4jfyyxt0w2a35823v8q48y9t8.private,
  amount: 100u64.private,
  _nonce: 5936375591335282851123442491152996062879930827774641867855677643278805858466group.public
}" 60u64

leo run submit_seed 12345field 31field

leo run register_ticket 12345field "{
  owner: aleo1t3ut4l0wnaf3rrkt7djtm0fflvl2tzhhm4jfyyxt0w2a35823v8q48y9t8.private,
  lottery_id: 12345field.private,
  amount: 60u64.private,
  _nonce: 5343738509398692058161122985249900799304520739358953017256597097760603501103group.public
}" 60u64


# Account C
echo "
NETWORK=testnet
PRIVATE_KEY=APrivateKey1zkpAY3kFSAreD8aVMJ4CEjimgT3TgQhAHLEU8hxme98ECST
ENDPOINT=https://api.explorer.provable.com/v1
" > .env

leo run buy_ticket 12345field "{
  owner: aleo12r9q2j3zutks9ypcdmhhanjlrry7mdwkn2zf055scher4yr4n5rsz6lkf7.private,
  amount: 100u64.private,
  _nonce: 3229223975362545266373364674066079129440576768531236097136889449096842113904group.public
}" 60u64

leo run submit_seed 12345field 53field

leo run register_ticket 12345field "{
  owner: aleo12r9q2j3zutks9ypcdmhhanjlrry7mdwkn2zf055scher4yr4n5rsz6lkf7.private,
  lottery_id: 12345field.private,
  amount: 60u64.private,
  _nonce: 620757402392706479677758394359657365638548531692806098064633930707262879100group.public
}" 60u64
```

4. Admin ends the submission phase

```
# Admin
echo "
NETWORK=testnet
PRIVATE_KEY=<YOUR_PRIVATE_KEY>
ENDPOINT=https://api.explorer.provable.com/v1
" > .env

leo run end_submission_phase 12345field

```

5. Admin conducts lottery drawing

```
leo run draw_winner 12345field
```

6. Winner claims their prize

```
# Account A
echo "
NETWORK=testnet
PRIVATE_KEY=APrivateKey1zkpHL8rPwuLVu94Qh5mFmaFFVgoMBa8vhvBPJo1g4WtYpmL
ENDPOINT=https://api.explorer.provable.com/v1
" > .env

leo run claim_prize 12345field "{
  owner: aleo16p0lgtzcsl0u86yd744pdu5nnnt5a23amaa9w8zecsge3v3sncxsk9lpm5.private,
  lottery_id: 12345field.private,
  amount: 60u64.private,
  _nonce: 6981604616755738770921301373037804368714632540946926235835869522463577314616group.public
}" 100u64

# Account B
echo "
NETWORK=testnet
PRIVATE_KEY=APrivateKey1zkpDM51iGRkHCWMGweKwgDiKSqztCCSYiz7UnpWoyt1eouX
ENDPOINT=https://api.explorer.provable.com/v1
" > .env

leo run claim_prize 12345field "{
  owner: aleo1t3ut4l0wnaf3rrkt7djtm0fflvl2tzhhm4jfyyxt0w2a35823v8q48y9t8.private,
  lottery_id: 12345field.private,
  amount: 60u64.private,
  _nonce: 5827915189700454969402155212914576103855105317713000538653359132064574806418group.public
}" 100u64

# Account C
echo "
NETWORK=testnet
PRIVATE_KEY=APrivateKey1zkpAY3kFSAreD8aVMJ4CEjimgT3TgQhAHLEU8hxme98ECST
ENDPOINT=https://api.explorer.provable.com/v1
" > .env

leo run claim_prize 12345field "{
  owner: aleo12r9q2j3zutks9ypcdmhhanjlrry7mdwkn2zf055scher4yr4n5rsz6lkf7.private,
  lottery_id: 12345field.private,
  amount: 60u64.private,
  _nonce: 3730641778643445590746680252724418941249507946686676452850053882945654303566group.public
}" 100u64

```

# Networking Testing

1. Admin mits tokens (mint_public)
   -You can see the tx on AleoScan and see the index 0 => connect wallet(make sure your wallet connects to mainnet) => see output#1 Record data => decrypt the record data on https://www.provable.tools/record, which is the Token Information.

```
# Admin environment setup
echo "
NETWORK=testnet
PRIVATE_KEY=<YOUR_PRIVATE_KEY>
ENDPOINT=https://api.explorer.provable.com/v1
" > .env

# Admin mints tokens to participants
# mint_public(receiver, amount)
leo execute --program basic_lottery_v4.aleo --broadcast mint_public aleo16p0lgtzcsl0u86yd744pdu5nnnt5a23amaa9w8zecsge3v3sncxsk9lpm5 200u64

leo execute --program basic_lottery_v4.aleo --broadcast mint_public aleo1t3ut4l0wnaf3rrkt7djtm0fflvl2tzhhm4jfyyxt0w2a35823v8q48y9t8 200u64

leo execute --program basic_lottery_v4.aleo --broadcast mint_public aleo12r9q2j3zutks9ypcdmhhanjlrry7mdwkn2zf055scher4yr4n5rsz6lkf7 200u64
```

2. Admin setups a loto（create_lottery）

```
# create_lottery(lottery_id, decription, prize_amount, max_parts, ticket_price)
leo execute --program basic_lottery_v4.aleo --broadcast create_lottery 12345field 20241219field 100u64 5u64 10u64
```

3. Participants purchase tickets (buy_ticket): using the Token information from the 1st step ⇒ submit seeds (submit_seed) ⇒ register tickets (register_ticket): using the Ticket information from buy_ticket
   - As well as the 1st step, you need to go to see the index 0 => connect wallet(make sure your wallet connects to mainnet) => see output#1 Record data => decrypt the record data on https://www.provable.tools/record, which is the Ticket Infomation.

```
# Account A
echo "
NETWORK=testnet
PRIVATE_KEY=APrivateKey1zkpHL8rPwuLVu94Qh5mFmaFFVgoMBa8vhvBPJo1g4WtYpmL
ENDPOINT=https://api.explorer.provable.com/v1
" > .env

leo execute --program basic_lottery_v4.aleo --broadcast buy_ticket 12345field "{
owner: aleo16p0lgtzcsl0u86yd744pdu5nnnt5a23amaa9w8zecsge3v3sncxsk9lpm5.private,
amount: 200u64.private,
_nonce: 6250168047376068379901370188551754454160630870076159063882068268378517910629group.public
}" 10u64

leo run submit_seed 12345field 17field

leo execute --program basic_lottery_v4.aleo --broadcast register_ticket 12345field "{
  owner: aleo16p0lgtzcsl0u86yd744pdu5nnnt5a23amaa9w8zecsge3v3sncxsk9lpm5.private,
  lottery_id: 12345field.private,
  amount: 10u64.private,
  _nonce: 620972053031830632372705066772042282980164727560142317699671808784830237599group.public
}" 10u64


# Account B
echo "
NETWORK=testnet
PRIVATE_KEY=APrivateKey1zkpDM51iGRkHCWMGweKwgDiKSqztCCSYiz7UnpWoyt1eouX
ENDPOINT=https://api.explorer.provable.com/v1
" > .env

leo execute --program basic_lottery_v4.aleo --broadcast buy_ticket 12345field "{
owner: aleo1t3ut4l0wnaf3rrkt7djtm0fflvl2tzhhm4jfyyxt0w2a35823v8q48y9t8.private,
amount: 200u64.private,
_nonce: 1955336875978717669748282197080110440609948019774962906345838156402196918515group.public
}" 10u64

leo execute --program basic_lottery_v4.aleo --broadcast submit_seed 12345field 123field

leo execute --program basic_lottery_v4.aleo --broadcast register_ticket 12345field "{
owner: aleo1t3ut4l0wnaf3rrkt7djtm0fflvl2tzhhm4jfyyxt0w2a35823v8q48y9t8.private,
lottery_id: 12345field.private,
amount: 10u64.private,
_nonce: 3347337125446501605394185554911690306653471109663434310564092021861481325578group.public
}" 10u64


# Account C
echo "
NETWORK=testnet
PRIVATE_KEY=APrivateKey1zkpAY3kFSAreD8aVMJ4CEjimgT3TgQhAHLEU8hxme98ECST
ENDPOINT=https://api.explorer.provable.com/v1
" > .env

leo execute --program basic_lottery_v4.aleo --broadcast buy_ticket 12345field "{
owner: aleo12r9q2j3zutks9ypcdmhhanjlrry7mdwkn2zf055scher4yr4n5rsz6lkf7.private,
amount: 200u64.private,
_nonce: 6260546474641922540017778328863586883663136179598605602550790649582206723440group.public
}" 10u64

leo execute --program basic_lottery_v4.aleo --broadcast submit_seed 12345field 53field

leo execute --program basic_lottery_v4.aleo --broadcast register_ticket 12345field "{
  owner: aleo12r9q2j3zutks9ypcdmhhanjlrry7mdwkn2zf055scher4yr4n5rsz6lkf7.private,
  lottery_id: 12345field.private,
  amount: 10u64.private,
  _nonce: 7512561801439491008039858540578802628715377772596977879770094221506430863744group.public
}" 10u64
```

4. Admin ends the submission phase

```
# Admin
echo "
NETWORK=testnet
PRIVATE_KEY=<YOUR_PRIVATE_KEY>
ENDPOINT=https://api.explorer.provable.com/v1
" > .env

leo execute --program basic_lottery_v4.aleo --broadcast end_submission_phase 12345field

```

5. Admin conducts lottery drawing

```
leo execute --program basic_lottery_v4.aleo --broadcast draw_winner 12345field

```

6. Winner claims their prize

```
# Account A
echo "
NETWORK=testnet
PRIVATE_KEY=APrivateKey1zkpHL8rPwuLVu94Qh5mFmaFFVgoMBa8vhvBPJo1g4WtYpmL
ENDPOINT=https://api.explorer.provable.com/v1
" > .env

leo execute --program basic_lottery_v4.aleo --broadcast claim_prize 12345field "{
owner: aleo16p0lgtzcsl0u86yd744pdu5nnnt5a23amaa9w8zecsge3v3sncxsk9lpm5.private,
lottery_id: 12345field.private,
amount: 10u64.private,
_nonce: 620972053031830632372705066772042282980164727560142317699671808784830237599group.public
}" 100u64

# Account B
echo "
NETWORK=testnet
PRIVATE_KEY=APrivateKey1zkpDM51iGRkHCWMGweKwgDiKSqztCCSYiz7UnpWoyt1eouX
ENDPOINT=https://api.explorer.provable.com/v1
" > .env

leo execute --program basic_lottery_v4.aleo --broadcast claim_prize 12345field "{
owner: aleo1t3ut4l0wnaf3rrkt7djtm0fflvl2tzhhm4jfyyxt0w2a35823v8q48y9t8.private,
lottery_id: 12345field.private,
amount: 10u64.private,
_nonce: 3347337125446501605394185554911690306653471109663434310564092021861481325578group.public
}" 100u64

# Account C
echo "
NETWORK=testnet
PRIVATE_KEY=APrivateKey1zkpAY3kFSAreD8aVMJ4CEjimgT3TgQhAHLEU8hxme98ECST
ENDPOINT=https://api.explorer.provable.com/v1
" > .env

leo execute --program basic_lottery_v4.aleo --broadcast claim_prize 12345field "{
owner: aleo12r9q2j3zutks9ypcdmhhanjlrry7mdwkn2zf055scher4yr4n5rsz6lkf7.private,
lottery_id: 12345field.private,
amount: 10u64.private,
_nonce: 7512561801439491008039858540578802628715377772596977879770094221506430863744group.public
}" 100u64

```

![If you claim with an account that hasn't won, tx won't be generated. you can see the image on AleoScan.](/images/winnerclaim_fails.png)
