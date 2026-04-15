



impl usize {
    fn clog(self) -> u32 {
        (usize::BITS - (self - 1).leading_zeros())
    }
}
