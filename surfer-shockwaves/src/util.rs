pub trait CLog {
    fn clog(self) -> u32;
}

impl CLog for usize {
    fn clog(self) -> u32 {
        if self == 0 {
            return 0;
        }
        usize::BITS - (self - 1).leading_zeros()
    }
}

impl CLog for u128 {
    fn clog(self) -> u32 {
        if self == 0 {
            return 0;
        }
        u128::BITS - (self - 1).leading_zeros()
    }
}
