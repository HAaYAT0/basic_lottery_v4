program basic_lottery_v4.aleo {
    mapping lottery_data: field => LotteryInfo;
    mapping ticket_count: field => u64;
    mapping participant_tickets: field => u64;
    mapping winner_ticket: field => u64;
    mapping prize_claimed: field => bool;
    mapping token_pool: field => u64;
    mapping account: address => u64;
    mapping lottery_admin: field => address;       
    mapping max_participants: field => u64;        
    mapping has_submitted: address => bool;        
    mapping submission_ended: field => bool;       
    mapping combined_seed_hash: field => field;    
    mapping seed_count: field => u64;

    struct LotteryInfo {
        description: field,
        prize_amount: u64,
        total_pool: u64,
        is_drawn: bool,
        ticket_price: u64 
    }

    record LotteryTicket {
        owner: address,
        lottery_id: field,
        amount: u64
    }

    record token {
        owner: address,
        amount: u64,
    }

    struct KeyInput {
        lottery_id: field,
        user: address,
    }

    struct PriceInfo {
        price: u64,
        lottery_exists: bool
    }

    async transition mint_public(
        public receiver: address,
        public amount: u64
    ) -> (token, Future) {
        let new_token: token = token {
            owner: receiver,
            amount: amount
        };
        return (new_token, mint_update_state(receiver, amount));
    }

    async function mint_update_state(
        receiver: address,
        amount: u64
    ) {
        let current_amount: u64 = Mapping::get_or_use(account, receiver, 0u64);
        Mapping::set(account, receiver, current_amount + amount);
    }

    inline generate_participant_key(lottery_id: field, owner: address) -> field {
        let input: KeyInput = KeyInput {
            lottery_id: lottery_id,
            user: owner,
        };
        return BHP256::hash_to_field(input);
    }

    async transition create_lottery(
        lottery_id: field,
        description: field,
        prize_amount: u64,
        max_parts: u64,
        ticket_price: u64
    ) -> Future {
        assert(ticket_price > 0u64);
        assert(max_parts > 0u64);
        assert(prize_amount > 0u64);
        
        return initialize_lottery(lottery_id, description, prize_amount, max_parts, ticket_price, self.caller);
    }

    async function initialize_lottery(
        lottery_id: field,
        description: field,
        prize_amount: u64,
        max_parts: u64,
        ticket_price: u64,
        admin: address
    ) {
        let info: LotteryInfo = LotteryInfo {
            description: description,
            prize_amount: prize_amount,
            total_pool: 0u64,
            is_drawn: false,
            ticket_price: ticket_price
        };

        assert(!Mapping::contains(lottery_data, lottery_id));

        Mapping::set(lottery_data, lottery_id, info);
        Mapping::set(ticket_count, lottery_id, 0u64);
        Mapping::set(token_pool, lottery_id, 0u64);
        Mapping::set(lottery_admin, lottery_id, admin);
        Mapping::set(max_participants, lottery_id, max_parts);
        Mapping::set(seed_count, lottery_id, 0u64);
        Mapping::set(submission_ended, lottery_id, false);
        Mapping::set(combined_seed_hash, lottery_id, 0field);
    }

    async transition buy_ticket(
        lottery_id: field,
        payment: token,
        expected_price: u64
    ) -> (LotteryTicket, Future) {
        assert_eq(payment.owner, self.caller);
        assert(payment.amount >= expected_price);
        assert(expected_price > 0u64);

        let ticket: LotteryTicket = LotteryTicket {
            owner: self.caller,
            lottery_id: lottery_id,
            amount: expected_price
        };

        let remainder_amount: u64 = payment.amount - expected_price;
        let remainder: token = token {
            owner: self.caller,
            amount: remainder_amount
        };

        return (ticket, verify_and_update_account(
            lottery_id,
            self.caller, 
            payment.amount, 
            remainder_amount, 
            expected_price
        ));
    }

    async function verify_and_update_account(
        lottery_id: field,
        buyer: address,
        payment_amount: u64,
        remainder_amount: u64,
        expected_price: u64
    ) {
        assert(Mapping::contains(lottery_data, lottery_id));
        
        let info: LotteryInfo = Mapping::get(lottery_data, lottery_id);
        
        assert(!info.is_drawn);
        
        assert_eq(expected_price, info.ticket_price);

        let curr_balance: u64 = Mapping::get_or_use(account, buyer, 0u64);
        assert(curr_balance >= payment_amount);
        
        let after_payment: u64 = curr_balance - payment_amount;
        let final_balance: u64 = after_payment + remainder_amount;
        Mapping::set(account, buyer, final_balance);
    }

    async transition register_ticket(
        lottery_id: field,
        ticket: LotteryTicket,
        amount: u64
    ) -> Future {
        assert_eq(ticket.owner, self.caller);
        assert_eq(ticket.lottery_id, lottery_id);
        assert_eq(ticket.amount, amount);
        
        return update_ticket_info(lottery_id, self.caller, amount);
    }

    async function update_ticket_info(
        lottery_id: field,
        buyer: address,
        amount: u64
    ) {
        let seed_done: bool = Mapping::get_or_use(has_submitted, buyer, false);
        assert(seed_done);

        assert(Mapping::contains(lottery_data, lottery_id));

        let current_count: u64 = Mapping::get_or_use(ticket_count, lottery_id, 0u64);
        let max_parts: u64 = Mapping::get(max_participants, lottery_id);
        assert(current_count < max_parts);
        
        let new_count: u64 = current_count + 1u64;

        let participant_key: field = generate_participant_key(lottery_id, buyer);
        Mapping::set(participant_tickets, participant_key, new_count);

        let current_pool: u64 = Mapping::get_or_use(token_pool, lottery_id, 0u64);
        Mapping::set(token_pool, lottery_id, current_pool + amount);

        let info: LotteryInfo = Mapping::get(lottery_data, lottery_id);
        assert(!info.is_drawn);
        
        let new_info: LotteryInfo = LotteryInfo {
            description: info.description,
            prize_amount: info.prize_amount,
            total_pool: info.total_pool + amount,
            is_drawn: info.is_drawn,
            ticket_price: info.ticket_price
        };
        Mapping::set(lottery_data, lottery_id, new_info);
        Mapping::set(ticket_count, lottery_id, new_count);
    }

    async transition submit_seed(
        lottery_id: field,
        seed_value: field
    ) -> Future {
        return store_seed(lottery_id, self.caller, seed_value);
    }

    async function store_seed(
        lottery_id: field,
        submitter: address,
        seed_value: field
    ) {
        let ended: bool = Mapping::get_or_use(submission_ended, lottery_id, false);
        assert(!ended);

        let already_submitted: bool = Mapping::get_or_use(has_submitted, submitter, false);
        assert(!already_submitted);

        let current_count: u64 = Mapping::get_or_use(seed_count, lottery_id, 0u64);
        let max_parts: u64 = Mapping::get(max_participants, lottery_id);
        assert(current_count < max_parts);

        let old_hash: field = Mapping::get_or_use(combined_seed_hash, lottery_id, 0field);
        let updated_hash: field = Poseidon2::hash_to_field(old_hash + seed_value);

        Mapping::set(combined_seed_hash, lottery_id, updated_hash);
        Mapping::set(seed_count, lottery_id, current_count + 1u64);
        Mapping::set(has_submitted, submitter, true);
    }

    async transition end_submission_phase(lottery_id: field) -> Future {
        return finalize_submission_end(lottery_id, self.caller);
    }

    async function finalize_submission_end(
        lottery_id: field,
        caller: address
    ) {
        let admin: address = Mapping::get(lottery_admin, lottery_id);
        assert_eq(caller, admin);

        Mapping::set(submission_ended, lottery_id, true);
    }

    async transition draw_winner(lottery_id: field) -> (Future) {
        return check_admin_and_draw(lottery_id, self.caller);
    }

    async function check_admin_and_draw(
        lottery_id: field,
        caller: address
    ) {
        let admin: address = Mapping::get(lottery_admin, lottery_id);
        assert_eq(caller, admin);

        let info: LotteryInfo = Mapping::get(lottery_data, lottery_id);
        assert(!info.is_drawn);

        let ended: bool = Mapping::get_or_use(submission_ended, lottery_id, false);
        assert(ended);

        let total_tickets: u64 = Mapping::get(ticket_count, lottery_id);
        assert(total_tickets > 0u64);

        let height_val: u32 = block.height;
        let reduced_height: u32 = height_val % 10000u32;
        let height_field: field = reduced_height as field;
        let height_hash: field = BHP256::hash_to_field(height_field);

        let combined: field = Mapping::get(combined_seed_hash, lottery_id);

        let final_hash_input: field = combined + height_hash;

        let random_u64: u64 = BHP256::hash_to_u64(final_hash_input);
        let mod_val: u64 = (random_u64 % (total_tickets as u64));
        let winning_number: u64 = mod_val as u64 + 1u64;

        Mapping::set(winner_ticket, lottery_id, winning_number);

        let new_info: LotteryInfo = LotteryInfo {
            description: info.description,
            prize_amount: info.prize_amount,
            ticket_price: info.ticket_price,
            total_pool: info.total_pool,
            is_drawn: true
        };
        Mapping::set(lottery_data, lottery_id, new_info);
    }

    async function verify_and_update_state(
        lottery_id: field,
        claimer: address,
        user_prize_amount: u64
    ) {
        let info: LotteryInfo = Mapping::get(lottery_data, lottery_id);
        assert(info.is_drawn);
        assert_eq(info.prize_amount, user_prize_amount);

        assert(!Mapping::get_or_use(prize_claimed, lottery_id, false));

        let participant_key: field = generate_participant_key(lottery_id, claimer);
        let assigned_number: u64 = Mapping::get(participant_tickets, participant_key);
        let w_number: u64 = Mapping::get(winner_ticket, lottery_id);
        assert_eq(assigned_number, w_number);

        let current_pool: u64 = Mapping::get(token_pool, lottery_id);
        assert(current_pool >= info.prize_amount);

        Mapping::set(token_pool, lottery_id, current_pool - info.prize_amount);
        Mapping::set(prize_claimed, lottery_id, true);

        let claimer_balance: u64 = Mapping::get_or_use(account, claimer, 0u64);
        Mapping::set(account, claimer, claimer_balance + user_prize_amount);
    }

    async transition claim_prize(
        lottery_id: field,
        ticket: LotteryTicket,
        user_prize_amount: u64
    ) -> (token, Future) {
        assert_eq(ticket.owner, self.caller);

        let prize_token: token = token {
            owner: self.caller,
            amount: user_prize_amount
        };

        return (prize_token, verify_and_update_state(lottery_id, self.caller, user_prize_amount));
    }
}